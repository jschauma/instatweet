Summary
=======
Posting Instagram pictures to Twitter is a bit of a
pain, since instagram links do not get a Twitter image
card, requiring the user to follow the link.

'instatweet' allows you to periodically poll an
instagram account and have it post new images to a
Twitter account.  That way, you can follow an
instagram account without having to have or use an
instagram account and without having to follow
individual links.

Since Instagram may require you to have a developer
API account with Facebook and kick you back to a login
screen, 'instatweet' will fall back to using
picuki.net to grab the image.

'instatweet' also supports pulling an image from
Tumblr posts.

In addition, 'instatweet' can also post images to a
given Mastodon server; for that, the authenticating
token needs to be stored in the file
~/.mstdn/<twitter-user>.

If the -f flag is given, then 'instatweet' will log
the picture ID in the given file and only tweet images
that are not included in that file.

'instatweet' uses the tweet(1) command-line utility to
post the picture.  This requires you to have set up
tweet(1) for the given account prior to using
'instatweet'.

Please see the manual page for details.

Example
=======
I have a crontab entry that cross-posts cartoons from
the New Yorker Instagram account to a Twitter and
Mastodon account I control:

```
30 */2 * * * instatweet -f /home/jschauma/.instatweet -i newyorkercartoons -t nycartoons -M mstdn.social
```

Requirements
============
[tweet](https://github.com/jschauma/tweet)

Perl with
* LWP::UserAgent
* LWP::Protocol::https
* JSON

---

```
NAME
     instatweet	 tweet images from an instagram account

SYNOPSIS
     instatweet [-dhv] [-c caption] [-M mastodon] [-T tumblr] -f seen
		-i instagram -t twitter

DESCRIPTION
     instatweet will fetch the latest image from the given instagram account and
     post it on Twitter.

OPTIONS
     The following options are supported by instatweet:

     -M mastodon   Also post to this Mastodon server.  Note: this requires the
		   authentication token for that server to be stored in the file
		   ~/.mstdn/<twitter-account>.

     -T tumblr	   Fetch images from this tumblr blog.

     -c caption	   Specify a caption instead of trying to derive it from
		   Instagram.

     -d		   Don't do anything, just show what would be done.

     -f seen	   Log the pictures to the file 'seen'; only tweet pictures not
		   in that file.

     -h		   Display help and exit.

     -i instagram  Fetch the latest image from this instagram account.

     -t twitter	   Post the image to this twitter account.

     -v		   Be verbose.	Can be specified multiple times.

DETAILS
     Posting Instagram pictures to Twitter is a bit of a pain, since instagram
     links do not get a Twitter image card, requiring the user to follow the
     link.

     instatweet allows you to periodically poll an instagram account and have it
     post new images to a Twitter account.  That way, you can follow an
     instagram account without having to have or use an instagram account and
     without having to follow individual links.

     If the -f flag is given, then instatweet will log the picture ID in the
     given file and only tweet images that are not included in that file.

     instatweet uses the tweet(1) command-line utility to post the picture.
     This requires you to have set up tweet(1) for the given account prior to
     using instatweet.

EXIT STATUS
     The instatweet utility exits0 on success, and>0 if an error occurs.

SEE ALSO
     tweet(1)

HISTORY
     instatweet was originally written by Jan Schaumann
     jschauma@netmeister.org in August 2016.

BUGS
     Please submit bug reports and feature requests by emailing the author.
```
