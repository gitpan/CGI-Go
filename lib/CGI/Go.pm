package CGI::Go;

use strict;
use warnings FATAL => 'all';

use autodie;

use CGI qw();
use DBI qw();
use Template qw();
use HTML::Entities qw();
use Apache::Session::MySQL qw();
use Data::Dumper qw();

use Apache2::Const qw(OK);

our $VERSION = '0.01';

sub handler
{
    my $r = shift;

    my $go = CGI::Go->new($r);

    my $uri = $$go{r}->uri();
    my $dbPage = $go->GetData("SELECT * FROM page WHERE uri = ?", $uri);
    my $package = $dbPage->[0]{package};
    eval "require $package";
    if ($@) {
       my $err = $@;
       if ($package =~ m#^Page::#) {
          $package = "CGI::Go";
       }
       else {
          die($err, "\n", $package);
       }
    }

    my $method = $r->method();
    my $ret = $package->$method($go);

    return $ret;
}

sub Dumper
{
    return(Data::Dumper::Dumper(@_));
}

sub GET
{
    my ($class, $go) = @_;

    $go->{r}->content_type("text/html");
    
    my $output = "";

    my $vars = {};

    if ($go->{in}) {
        while (my ($key, $value) = each %{ $go->{in} }) {
            $vars->{form}{$key} = $go->{html_encode}->($value);
        }
    };

    my $ret = $go->Page(\$output, vars => $vars);

    $go->{r}->print($output);

    return Apache2::Const::OK;
}

sub new
{
    my $self = shift;
    my $class = ref($self) || __PACKAGE__;
    my $r = shift;

    my $obj = {};
    $obj->{r} = $r;

    my $cgi = CGI->new($r);

    $obj->{in} = $cgi->Vars();
    
    $obj->{html_encode} = \&HTML::Entities::encode_entities;
    $obj->{html_decode} = \&HTML::Entities::decode_entities;

    $obj->{dbh} = DBI->connect(undef, undef, undef, { RaiseError => 1, AutoCommit => 0 });

    $obj->{session} = $r->pnotes("InfoServantAuth");

    bless($obj, $class);

    return($obj);
}

sub GetData
{
    my ($self, $sql, $vars, %opts) = @_;

    my $ret = undef;

    if ($vars) {
        $ret = $self->{dbh}->selectall_arrayref($sql, { Slice => {} }, $vars);
    }
    else {
        $ret = $self->{dbh}->selectall_arrayref($sql, { Slice => {} });
    }

    return($ret);
}

sub UpdateData
{
    my ($self, $sql, $vars, %opts) = @_;

    my $ret = undef;

    if ($vars) {
        $ret = $self->{dbh}->do($sql, undef, $vars);
    }
    else {
        $ret = $self->{dbh}->do($sql, undef);
    }

    return($ret);
}

sub Page
{
    my ($self, $output, %opts) = @_;

    my $uri = $$self{r}->uri();

    my $dbRoot = $self->GetData("SELECT * FROM config WHERE `key` = 'ROOT_PAGE'");
    my $root = $dbRoot->[0]{value};

    my $dbTmpl = $self->GetData("SELECT * FROM page WHERE uri = ?", $uri);
    my $tmpl = $dbTmpl->[0]{template};

    if (!$root || !$tmpl) {
        return(undef);
        # die(sprintf("Nothing found for %s\n", $uri));
    }
    else {
        # warn("root: $root: tmpl: $tmpl: uri: $uri");
    }

    my $config = {
        INCLUDE_PATH => $root,
    };
    my $template = Template->new($config);
    my $ret = $template->process($tmpl, $opts{vars}, $output);
    die $template->error() unless $ret;

    return($ret);
}

sub DESTROY
{
    my $self = shift;

    $self->{dbh}->rollback();
}

package CGI::Go::Util;

use strict;
use warnings FATAL => 'all';

use autodie;

sub stack
{
	my ($class, $go) = @_;

	foreach my $lvl (0 .. 100) {
		my ($package, $filename, $line, $subroutine) = caller($lvl);

		if ($package && $filename && $line && $subroutine) {
			warn("$filename :: $line :: $package :: $subroutine\n");
		}
		else {
			last;
		}
	}
}

1;

__END__

=pod

=head1 NAME

CGI::Go - Let's go make another URL dispatcher

=head1 SYNOPSIS

    <Location />
       SetHandler modperl
       PerlResponseHandler CGI::Go
    </Location>

With the correct environment, this should allow you to have a functioning 
framework for web development.

=head1 DESCRIPTION

CGI::Go is an attempt to make a framework that I like, is extensible, and
possibly other people would like.

Currently it supports:

=over

=over

=item Sessions

=item Templates

=item Authentication

=item URL Mapping

=item METHOD invocation

=item Rapid prototyping

=item DBI Layer

=item HTML Encoding

=back

=back

=head1 EXAMPLE

The first part is to configure Apache; it is the entry point.

    # 
    # The frameowrk, session, and authencation modules.
    #

    PerlModule CGI::Go
    PerlModule Apache2::AuthCookieDBI
    PerlModule Apache::Session::MySQL

    <VirtualHost 127.0.0.1:80>
        ServerAdmin webmaster@exampledomain.com
        DocumentRoot "/opt/exampledomain.com/apache"

        ServerName www.exampledomain.com
        ServerAlias exampledomain.com

        ErrorLog logs/exampledomain.com-error_log
        CustomLog logs/exampledomain.com-access_log combined

        # authentication and session config
        PerlSetVar ExampleDomainAuthPath /
        PerlSetVar ExampleDomainAuthLoginScript /login
        PerlSetVar ExampleDomainAuthDBI_DSN "dbi:mysql:database=exampledomain;host=localhost"
        PerlSetVar ExampleDomainAuthDBI_SecretKey "3C9DCB80669AB3B9BC83DE3504477C30DAE26260417289913961FCEF1F1DCB06"
        PerlSetVar ExampleDomainAuthDBI_User mysecret 
        PerlSetVar ExampleDomainAuthDBI_Password mysecret
        PerlSetVar ExampleDomainAuthDBI_CryptType "md5"
        PerlSetVar ExampleDomainAuthDBI_SessionModule "Apache::Session::MySQL"
        PerlSetVar ExampleDomainAuthCookieName "ExampleDomainAuth"

        # the normal site
        <Location />
           SetHandler modperl
           PerlResponseHandler CGI::Go
           PerlSetEnv DBI_DSN dbi:mysql:database=exampledomain;host=localhost
           PerlSetEnv DBI_USER mysecret
           PerlSetEnv DBI_PASS mysecret

           AuthType Apache2::AuthCookieDBI
           AuthName ExampleDomainAuth
           PerlAuthenHandler Apache2::AuthCookieDBI->authenticate
           PerlAuthzHandler Apache2::AuthCookieDBI->authorize

           require valid-user
        </Location>

        # the login
        <Location /logmein>
           AuthType Apache2::AuthCookieDBI
           AuthName ExampleDomainAuth
           SetHandler modperl
           PerlHandler Apache2::AuthCookieDBI->login

           PerlSetEnv DBI_DSN dbi:mysql:database=exampledomain;host=localhost
           PerlSetEnv DBI_USER mysecret
           PerlSetEnv DBI_PASS mysecret

           satisfy any
        </Location>
    </VirtualHost>

Once Apache is working the DB should be setup.  Currently MySQL is used:

    CREATE TABLE `config` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `inserted` timestamp NOT NULL DEFAULT '1970-01-01 00:00:01',
        `updated` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP,
        `key` enum('ROOT_PAGE') NOT NULL,
        `value` varchar(512) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `CONFIG_KEYPAIR_IDX` (`key`,`value`)
    ) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1

    CREATE TABLE `page` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `inserted` timestamp NOT NULL DEFAULT '1970-01-01 00:00:01',
        `updated` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP,
        `uri` varchar(512) NOT NULL,
        `template` varchar(255) NOT NULL,
        `package` varchar(255) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uri` (`uri`)
    ) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1

    CREATE TABLE `sessions` (
        `id` char(32) NOT NULL,
        `a_session` text,
    PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1

    INSERT INTO config (inserted, `key`, `value`) VALUES (NOW(), 'ROOT_PAGE', '/opt/template');

    INSERT INTO page (inserted, uri, template, package) VALUES (NOW(), '/', 'index.tpl', 'Page::Index');
    INSERT INTO page (inserted, uri, template, package) VALUES (NOW(), '/login', 'login.tpl', 'Page::Login');
    INSERT INTO page (inserted, uri, template, package) VALUES (NOW(), '/login/', 'login.tpl', 'Page::Login');
    INSERT INTO page (inserted, uri, template, package) VALUES (NOW(), '/example', 'example.tpl', 'Page::Example');
    INSERT INTO page (inserted, uri, template, package) VALUES (NOW(), '/example/', 'example.tpl', 'Page::Example');

    # user table here

The next piece is the templates.  We need a index page, login page, and an authenticated page.

index.tpl

    <!DOCTYPE HTML>
    <html>
    <head>

    <meta charset="utf-8"> 
    <title>Index</title> 

    </head>

    <table>
        <tr><td align="center"><a href=/example>Overview</a></td></tr>
    </table>

    </body>
    </html>

login.tpl

    <!DOCTYPE HTML>
    <html>
    <head>

    <meta charset="utf-8"> 
    <title>Login</title> 

        <style type="text/css">
        table
        {
            border-collapse:collapse;
        }

        table, td, th
        {
            border:1px solid black;
        }
        </style>

    </head>

    <form action=/logmein>
    <input type="hidden" name="destination" value="/">
    <table>
        <tr><td>Username:</td><td><input type=textfield name=credential_0 value="[% form.credential_0 %]"></td></tr>
        <tr><td>Password:</td><td><input type=password name=credential_1 value="[% form.credential_1 %]"></td></tr>
        <tr><td colspan=2 align=left><input type=submit name=submit value=Submit></td></tr>
    </table>
    </form>

    </body>
    </html>

example.tpl

    <!DOCTYPE HTML>
    <html>
    <head>

    <meta charset="utf-8"> 
    <title>Example</title> 

    </head>

    <table>
        <tr><td align="center">Hi</td></tr>
    </table>

    </body>
    </html>

Now the pages should be accessible via http://exampledomain.com to get a login page.

The dispatcher looks up the template and module to call via a database call which is
keyed by the URI.  The module is either loaded or a default is used.  Given that, the
Package::METHOD is invoked - for example Page::Index::GET (currently only GET is 
supported).  The METHOD retrieves the template and displays it.

=cut
