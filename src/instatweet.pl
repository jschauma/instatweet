#! /usr/pkg/bin/perl -T
#
# This tool fetches the latest image from the given
# instagram account and posts it on twitter.

use strict;
use warnings;

use File::Basename;
use File::Temp;
use Getopt::Long;
Getopt::Long::Configure("bundling");
use JSON;
use LWP::UserAgent;

$ENV{'PATH'} = "/home/jschauma/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin";
$ENV{'CDPATH'} = "";
$ENV{'ENV'} = "";
$ENV{'HOME'} = "/tmp";

###
### Constants
###

use constant EXIT_FAILURE => 1;
use constant EXIT_SUCCESS => 0;

###
### Globals
###

my %CONFIG;
my $PROGNAME = basename($0);
my ($TMPDIR, $TMPFILE);

my ($CAPTION, $CODE, $LINK);

###
### Subroutines
###

sub checkSeen() {
	if (!$CONFIG{'f'}) {
		return;
	}

	verbose("Checking if we've seen $CODE in " . $CONFIG{'f'} . "...", 2);

	my $file = $CONFIG{'f'};

	if (!-f $file) {
		return;
	}

	my $seen = `cat $file`;
	chomp($seen);
	my %all = map{ $_ => 1 } split(/\n/, $seen);

	return $all{$CODE};
}

sub error($$) {
	my ($msg, $err) = @_;
	print STDERR "$msg\n";
	exit($err);
	#NOTREACHED
}

sub init() {
	my ($ok);

	if (!scalar(@ARGV)) {
		error("I have nothing to do.  Try -h.", EXIT_FAILURE);
		# NOTREACHED
	}

	$ok = GetOptions(
			 "dont|d"        => \$CONFIG{'d'},
			 "file|f=s"      => \$CONFIG{'f'},
			 "help|h"        => \$CONFIG{'h'},
			 "instagram|i=s" => \$CONFIG{'i'},
			 "twitter|t=s"   => \$CONFIG{'t'},
			 "verbose|v+"    => sub { $CONFIG{'v'}++; },
			 );

	if (scalar(@ARGV)) {
		error("I can't deal with spurious arguments after flags.  Try -h.", EXIT_FAILURE);
		# NOTREACHED
	}

	if ($CONFIG{'h'} || !$ok) {
		usage($ok);
		exit(!$ok);
		# NOTREACHED
	}

	if (!$CONFIG{'i'} || !$CONFIG{'t'}) {
		error("Please specify both '-i' and '-t'.", EXIT_FAILURE);
		# NOTREACHED
	}

	if ($CONFIG{'i'} =~ m/^([a-z0-9]+)$/) {
		$CONFIG{'i'} = $1;
	} else {
		error("Invalid instagram account name.", EXIT_FAILURE);
		# NOTREACHED
	}

	if ($CONFIG{'f'}) {
		if ($CONFIG{'f'} =~ m/^([a-z0-9\~\/._-]+)$/) {
			$CONFIG{'f'} = $1;
		} else {
			error("Unsafe file name '" . $CONFIG{'f'} . "'.", EXIT_FAILURE);
			# NOTREACHED
		}
	}
}

sub fetchMedia($) {
	my ($link) = @_;

	verbose("Fetching media file '$link'...", 2);

	$TMPDIR = File::Temp->newdir(CLEANUP => 1);
	$TMPFILE = File::Temp->new(UNLINK => 1, DIR => $TMPDIR, SUFFIX => '.jpg');

	if (!$CONFIG{'d'}) {
		print $TMPFILE join("\n", getContent($link));
	}
}

sub getContent($) {
	my ($url) = @_;

	$ENV{HTTPS_DEBUG} = 1;
	my $ua = LWP::UserAgent->new();
	$ua->ssl_opts("SSL_ca_file" => "/etc/openssl/cert.pem");
	$ua->agent("");
	my $response = $ua->get($url);
	if (!$response->is_success) {
		error("Unable to fetch $url: " . $response->status_line, EXIT_FAILURE);
		# NOTREACHED
	}
	return split(/\n/, $response->content);
}

sub getLatestPic() {
	verbose("Fetching latest image for instagram account '" . $CONFIG{'i'} . "'...");

	my $url = "https://www.picuki.com/profile/" . $CONFIG{'i'};

	foreach my $line (getContent($url)) {
		if ($line =~ m|<a href="https://www.picuki.com/media/(.*)">|) {
			my $media = $1;
			$CODE = mediaToCode($media);
			next;
		}

		if ($line =~ m/<img class="post-image" src="(.*)" alt="(.*)">/) {
			my $file = $1;
			$CAPTION = $2;
			$LINK = "https://www.instagram.com/p/$CODE/";
			fetchMedia($file);
			last;
		}
	}

	if (!$CODE) {
		error("Unable to get data from instagram.", EXIT_FAILURE);
		# NOTREACHED
	}
}

sub mediaToCode($) {
	my ($id) = @_;
	my $code  = "";
	my @alphabet = split("", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_");

	my $n = int($id);
	while ($n > 0) {
		my $r = $n % 64;
		$n = int(($n - $r) / 64);
		$code = $alphabet[$r] . $code;
	}

	return $code;
}


sub runCommand($) {
	my ($cmd) = @_;
	verbose("Running '$cmd'...", 2);
	if ($CONFIG{'d'}) {
		print "$cmd\n";
	} else {
		system($cmd);
	}
}

sub tweetPic() {
	verbose("Tweeting picture...");

	if ($CAPTION && (length($CAPTION) > 89)) {
		$CAPTION = substr($CAPTION, 0, 86) . "...";
	}

	if (!$CAPTION) {
		$CAPTION = "";
	}

	my $seen = checkSeen();

	if ($CONFIG{'f'} && $seen) {
		verbose("Already tweeted picture '$CODE'.");
		return;
	}

	my @cmd = ( "tweet", "-u", $CONFIG{'t'}, "-m", $TMPFILE );
	binmode(STDOUT, ":utf8");
	binmode(STDERR, ":utf8");
	verbose("'$CAPTION $LINK' | " . join(" ", @cmd), 2);
	open(PIPE, "|-", @cmd) || die "Unable to open pipe to 'tweet': $!\n";
	binmode(PIPE, ":utf8");
	print PIPE "$CAPTION $LINK";
	close(PIPE);

	if ($CONFIG{'f'}) {
		my $cmd = "echo '$CODE' >> " . $CONFIG{'f'};
		runCommand($cmd);
	}
}

sub usage($) {
	my ($err) = @_;

	my $FH = $err ? \*STDERR : \*STDOUT;

	print $FH <<EOH
Usage: $PROGNAME [-dhv] -i instagram -t twitter
         -d            don't do anything, just show what would be done
	 -h            print this help and exit
         -i instagram  fetch photos from the 'instagram' account
         -t twitter    post photos to the 'twitter' account
	 -v            increase verbosity
EOH
}

sub verbose($;$) {
	my ($msg, $level) = @_;
	my $char = "=";

	return unless $CONFIG{'v'};

	$char .= "=" x ($level ? ($level - 1) : 0 );

	if (!$level || ($level <= $CONFIG{'v'})) {
		print STDERR "$char> $msg\n";
	}
}

###
### Main
###

init();
getLatestPic();
tweetPic();

exit(0);
