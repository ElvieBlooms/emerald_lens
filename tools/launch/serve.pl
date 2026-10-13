#!/usr/bin/perl
# Serves the tools folder to this computer only, for the sprite tools page.
# The fallback when Python 3 isn't usable: Perl comes with macOS and most
# Linux systems. Core modules only. -Elvie
use strict;
use warnings;
use IO::Socket::INET;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

my $root = dirname(dirname(abs_path($0)));
my %types = (
  html => 'text/html; charset=utf-8', css => 'text/css; charset=utf-8',
  js => 'text/javascript', mjs => 'text/javascript', json => 'application/json',
  png => 'image/png', gif => 'image/gif', jpg => 'image/jpeg', jpeg => 'image/jpeg', webp => 'image/webp',
  svg => 'image/svg+xml', ico => 'image/x-icon', wasm => 'application/wasm', zip => 'application/zip',
  whl => 'application/zip', py => 'text/plain; charset=utf-8', md => 'text/plain; charset=utf-8',
  txt => 'text/plain; charset=utf-8', ttf => 'font/ttf', woff2 => 'font/woff2',
);

my ($server, $port);
for my $p (8765 .. 8790) {
  $server = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $p, Listen => 32, ReuseAddr => 1, Proto => 'tcp');
  if ($server) { $port = $p; last; }
}
die "Couldn't find a free port between 8765 and 8790. Close other copies of this window and try again.\n" unless $server;

my $url = "http://127.0.0.1:$port/web/";
print "\n  Emerald Lens sprite tools\n  Open $url in your browser (it should open by itself).\n",
      "  Leave this window open while you use the tools; close it to stop.\n\n";
if ($^O eq 'darwin') { system('open', $url); }
elsif ($^O eq 'MSWin32') { system('start', '', $url); }
else { system("xdg-open '$url' >/dev/null 2>&1 &"); }

$SIG{PIPE} = 'IGNORE';
while (my $c = $server->accept) {
  binmode $c;
  my $line = <$c>;
  next unless defined $line;
  # read the headers to the blank line; nothing in them is needed
  while (my $h = <$c>) { last if $h =~ /^\r?\n$/; }
  my ($method, $target) = $line =~ m{^(GET|HEAD) (\S+)};
  unless ($method) { reply($c, 405, 'text/plain', 'Method not allowed'); next; }
  my $path = (split /\?/, $target)[0];
  $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
  my @parts = grep { length } split m{/}, $path;
  if (grep { $_ eq '..' || /^\./ || /[\\:]/ } @parts) { reply($c, 404, 'text/plain', 'Not found'); next; }
  my $full = File::Spec->catfile($root, @parts);
  if (-d $full) {
    if ($path !~ m{/$}) { redirect($c, "$path/"); next; }
    $full = File::Spec->catfile($full, 'index.html');
  }
  unless (-f $full && open(my $fh, '<:raw', $full)) { reply($c, 404, 'text/plain', 'Not found'); next; }
  else {
    local $/;
    my $body = <$fh> // '';
    close $fh;
    my ($ext) = $full =~ /\.([^.\/]+)$/;
    reply($c, 200, $types{lc($ext // '')} // 'application/octet-stream', $method eq 'HEAD' ? undef : $body, length $body);
  }
}

sub reply {
  my ($c, $code, $type, $body, $len) = @_;
  my %why = (200 => 'OK', 404 => 'Not Found', 405 => 'Method Not Allowed');
  $len //= length($body // '');
  print $c "HTTP/1.1 $code $why{$code}\r\nContent-Type: $type\r\nContent-Length: $len\r\n",
           "Cache-Control: no-cache\r\nConnection: close\r\n\r\n";
  print $c $body if defined $body;
  close $c;
}

sub redirect {
  my ($c, $to) = @_;
  print $c "HTTP/1.1 301 Moved Permanently\r\nLocation: $to\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
  close $c;
}
