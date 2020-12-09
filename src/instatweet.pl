#! /usr/pkg/bin/perl -T
#
# This tool fetches the latest image from the given
# instagram account and posts it on twitter.

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Temp;
use Getopt::Long;
Getopt::Long::Configure("bundling");
use JSON;
use LWP::UserAgent;

$ENV{'PATH'} = "/home/jschauma/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin";
$ENV{'CDPATH'} = "";
$ENV{'ENV'} = "";
$ENV{'HOME'} = "/home/jschauma";

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

sub getMD5() {
	verbose("Calculating md5 of $TMPFILE...");
	my $fh;
	open($fh, '<', $TMPFILE) or die "Unable to open $TMPFILE: $!\n";
	$CODE = Digest::MD5->new->addfile($fh)->hexdigest;
	close($fh);
	verbose("MD5($TMPFILE): $CODE", 2);
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
			 "tumblr|T=s"    => \$CONFIG{'T'},
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

	if (!($CONFIG{'i'} || $CONFIG{'T'})|| !$CONFIG{'t'}) {
		error("Please specify both '-t' and either '-i' or '-T'.", EXIT_FAILURE);
		# NOTREACHED
	}

	if ($CONFIG{'i'}) {
		if ($CONFIG{'i'} =~ m/^([a-z0-9]+)$/) {
			$CONFIG{'i'} = $1;
		}
	} elsif ($CONFIG{'T'}) {
		if ($CONFIG{'T'} =~ m/^([a-z0-9]+)$/) {
			$CONFIG{'T'} = $1;
		}
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

	if ($CONFIG{'T'}) {
		verbose("Fetching latest image for Tumblr account '" . $CONFIG{'T'} . "'...");
		tryTumblr();
	} else {
		verbose("Fetching latest image for instagram account '" . $CONFIG{'i'} . "'...");
		tryInstagram();

		if (!$LINK) {
			tryPicuki();
		}
	}

	if (!$LINK) {
		error("Unable to get data.", EXIT_FAILURE);
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

sub tryInstagram() {
	verbose("Trying instagram...", 2);

 	my $url = "https://www.instagram.com/" . $CONFIG{'i'} . "/?__a=1";

	foreach my $line (getContent($url)) {
		if ($line =~ m/javascript">window._sharedData = (.*);<\/script>/) {
			my $jdata;
		        my $json = new JSON;
			eval {
				$jdata = $json->allow_nonref->utf8->relaxed->decode($1);
			};
			if ($@) {
				error("Unable to parse json:\n" . $@, EXIT_FAILURE);
				# NOTREACHED
			}

			if (!$jdata->{entry_data}) {
				last;
			}

			if ($jdata->{entry_data}->{LoginAndSignupPage}) {
				#print STDERR "Instagram redirects to login page.\n";
				last;
			}

			my $node= @{@{$jdata->{entry_data}->{ProfilePage}}[0]->{graphql}->{user}->{edge_owner_to_timeline_media}->{edges}}[0]->{node};

			my $file = $node->{thumbnail_src};

			if (!$file) {
				$file = $node->{display_url};
			}

			if (!$file) {
				error("Unable to find a source file at $url.", EXIT_FAILURE);
				# NOTREACHED
			}

			$CAPTION = $node->{edge_media_to_caption}->{edges}[0]->{node}->{text};

			if ($CAPTION) {
				$CAPTION =~ s/\n/ /g;
			}

			$CODE = $node->{shortcode};
			if ($CODE =~ m/^([a-zA-Z0-9_-]+)$/) {
				$CODE = $1;
			} else {
				error("Unsafe image code: $CODE.", EXIT_FAILURE);
				# NOTREACHED
			}
			$LINK = "https://www.instagram.com/p/$CODE/";
			fetchMedia($file);
			last;
		}
	}
}

sub tryPicuki() {
	verbose("Trying picuki...", 2);

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
			if ($CODE) {
				$LINK = "https://www.instagram.com/p/$CODE/";
			} else {
				$LINK = "https://www.instagram.com/newyorkercartoons/";
			}
			fetchMedia($file);
			last;
		}
	}

	if (!$CODE && $TMPFILE) {
		getMD5();
	}
}

sub tryTumblr() {
	verbose("Trying tumblr...", 2);

	my $url = "https://" . $CONFIG{'T'} . ".tumblr.com";

	my $item = 0;
	my $post = "";
	foreach my $line (getContent($url . "/rss")) {
		if ($line =~ m|<item>.*?<link>($url/post/(.*?))</link>|) {
			$post = $1;
			$CODE = $2;
			last;
		}
	}
	if ($post) {
		foreach my $line (getContent($post)) {
			if ($line =~ m|<a href="$url/image/.*?"><img src="(.*?)"|) {
				$LINK = $post;
				fetchMedia($1);
				last;
			}
		}
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
		verbose("Already tweeted picture '$CODE' with caption '$CAPTION'.");
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
Usage: $PROGNAME [-dhv] [-T tumblr] [-i instagram] -t twitter
         -T tumblr     fetch photos from the 'tumblr' account
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
