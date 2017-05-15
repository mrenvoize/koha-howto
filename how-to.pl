#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use CGI qw ( -utf8 );

use C4::Output;
use C4::Auth;

my $query = new CGI;

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "how-to.tt",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => '*' },
    }
);

# TODO - put into kohadevbox
our $bugz = `which bugz`;
chomp $bugz;
die "You need to install bugz: `apt install bugz`" unless $bugz;

our $bug_number = 18584;
my ( @messages, @step_messages );
my ( $step, $substep, $next_step, $next_substep );
$step    = $query->param('step')    || 0;
$substep = $query->param('substep') || '';

if ( $step == 4 ) {
    $next_step = $step;
    if ($substep) {
        $next_substep = get_next_substep($substep);
    }
    else {
        $next_substep = 'a';
    }
    #$substep = get_next_substep($substep);

    # FIXME $next_step = $step + 1; IF next_substep does not exit
    my $verify = $query->param('verify') || 0;
    if ( $substep eq 'a' and $verify ) {
        @step_messages = get_issues_with_branch();

        @step_messages = get_issues_with_last_commit() unless @step_messages;
    }
    elsif ( $substep eq 'b' and $verify ) {
        push @step_messages, 'not_executed'
            unless is_qa_tests_have_been_executed();
    }
    elsif ( $substep eq 'c' and $verify ) {
        push @step_messages, 'report_not_nso'
            unless is_bug_nso($bug_number);
    }
    elsif ( $substep eq 'd' and $verify ) {
        @step_messages = get_issues_with_branch();

        unless (@step_messages) {
            push @step_messages, 'patch_not_applied'
                unless is_patch_applied();
        }
    }
    elsif ( $substep eq 'e' and $verify ) {
        push @step_messages, 'patch_not_signed_off'
            unless is_patch_signed_off();
    }
    elsif ( $substep eq 'f' and $verify ) {
        push @step_messages, 'report_not_so'
            unless is_bug_so($bug_number);
        $next_step    = 5;
        $next_substep = '';
    }
    $substep = get_next_substep($substep) if $verify and not @step_messages;
}
else {
    $next_step = $step + 1;
}

my $patron = Koha::Patrons->find($loggedinuser);
unless ($patron) {
    push @messages, { type => 'error', code => 'using_db_user' };
}

$template->param(
    step          => $step,
    next_step     => $next_step,
    substep       => $substep,
    next_substep  => $next_substep,
    messages      => \@messages,
    step_messages => \@step_messages,
);
output_html_with_http_headers $query, $cookie, $template->output;

sub get_next_substep {
    my ($substep) = @_;
    my $substeps = q|abcdefgh|;
    return substr( $substeps, index( $substeps, $substep ) + 1, 1 );
}

sub get_current_branch {
    my $br = qx{ git branch|grep '*' };
    $br =~ s/\* //g;
    chomp $br;
    return $br;
}

sub get_issues_with_branch {
    my $ls = `ls Koha/*.pm`;
    return ('no_koha_git_dir') unless $ls;
    my $branch = get_current_branch();
    my @messages;
    unless ( $branch =~ m|$bug_number| ) {
        push @messages, 'branch_without_bugnumber';
    }
    my $nb_commits_diff = `git log origin/master..HEAD --oneline | wc -l`;
    chomp $nb_commits_diff;
    if ( $nb_commits_diff > 1 ) {
        push @messages, 'too_many_commits_diff_with_master';
    }
    $nb_commits_diff = `git log HEAD..origin/master --oneline | wc -l`;
    chomp $nb_commits_diff;
    if ( $nb_commits_diff > 0 ) {
        push @messages, 'too_many_commits_diff_with_master';
    }

    return @messages;
}

sub is_patch_applied {
    my $last_commit = `git log --oneline -1`;
    chomp $last_commit;
    my @w = split ' ', $last_commit;
    return 0 if $w[1] ne 'Bug' or $w[2] ne '18584:';
    return 1;
}

sub is_patch_signed_off {
    my $last_commit = `git log -1`;
    chomp $last_commit;
    $last_commit =~ s|\n\s*|\n|g;
    return ( $last_commit =~ m|\nSigned-off-by: | );
}

sub get_issues_with_last_commit {
    my $last_commit = `git log -1`;
    chomp $last_commit;
    $last_commit =~ s|\n\s*|\n|g;
    my @lines = split "\n", $last_commit;
    $_ =~ s|^\s*|| for @lines;
    my $first_line = $lines[3];
    my @messages;
    unless ( $first_line =~ m|^Bug $bug_number: | ) {
        push @messages, 'commit_does_not_start_with_bug_number';
    }
    unless ( $first_line =~ m|space| ) {
        push @messages, 'commit_does_not_contain_spaces';
    }

    if ( length($first_line) > 80 ) {
        push @messages, 'first_line_too_long';
    }

    my $status = `git log --oneline --name-status -1`;
    chomp $status;
    my @status_lines = split "\n", $status;
    if ( @status_lines > 2 ) {
        push @messages, 'too_many_files_modified';
    }
    else {
        my $modified_file = $status_lines[1];
        $modified_file =~ s|^M\s*||;
        $modified_file =~ s|.*/(.*\.p[lm])$|$1|;
        unless ( $first_line =~ $modified_file ) {
            push @messages, 'commit_message_does_not_contain_filename';
        }
    }

# FIXME (?) Raised on STDERR: warning: unable to access '/root/.config/git/attributes': Permission denied
    my $stats = `git log --oneline --shortstat -1 2> /dev/null`;
    chomp $stats;
    my @stats_lines = split "\n", $stats;

    # 1 file changed, 1 insertion(+), 2 deletions(-)
    if ( $stats_lines[1] !~ m|1 insertion| or $stats_lines[1] !~ m|1 deletion| )
    {
        push @messages, 'too_many_lines_modified';
    }

    unless ( $last_commit =~ m|\nTest plan:| ) {
        push @messages, 'commit_message_does_not_contain_test_plan';
    }

    return @messages;
}

sub is_qa_tests_have_been_executed {
    my $qa_prev_commit = `git log qa-prev-commit --oneline -1 2> /dev/null`;
    my $HEAD_1         = `git log HEAD~1 --oneline -1`;
    return $qa_prev_commit eq $HEAD_1 ? 1 : 0;
}

sub is_bug_nso {
    my ($bz_number) = @_;
    my $status = get_bz_status($bz_number);
    return $status eq 'Needs Signoff' ? 1 : 0;
}

sub is_bug_so {
    my ($bz_number) = @_;
    my $status = get_bz_status($bz_number);
    return $status eq 'Signed Off' ? 1 : 0;
}

sub get_bz_status {
    my ($bz_number) = @_;
    my $bugzilla_urlbase =
      q|https://bugs.koha-community.org/bugzilla3/xmlrpc.cgi|;
    my $bugz_output = `$bugz -b $bugzilla_urlbase --skip-auth get -n $bz_number | grep '^Status'`;
    my ($status) = ( $bugz_output =~ /^Status *: (.*)/ );
    return $status;
}
