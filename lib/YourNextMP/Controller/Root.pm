package YourNextMP::Controller::Root;

use strict;
use warnings;
use parent qw/Catalyst::Controller/;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

YourNextMP::Controller::Root - Root Controller for YourNextMP

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 auto

Carry out some checks to see that the request can be served.

If there is a user check that they have granted us copyright.

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    # If we have a user check that the copyright has been handed over
    if ( $c->user_exists && !$c->user->copyright_granted ) {
        my $divert_url = '/users/grant_copyright';
        $c->divert_to($divert_url)
          unless $c->req->uri->path eq $divert_url;
    }

    return 1;
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{seats}      = $c->db('Seat')->search();
    $c->stash->{parties}    = $c->db('Party')->search();
    $c->stash->{candidates} = $c->db('Candidate')->search();

    # generate the list of top parties
    my $top_parties = $c->db('Party')->search(
        undef,    #
        {
            join   => 'candidates',
            select => [
                'me.code',    #
                'me.name',    #
                { count => 'candidates.id' }
            ],
            as       => [qw( code name candidate_count )],
            group_by => [ 'me.code', 'me.name' ],

            order_by => 'count desc, me.code',
            rows     => 10,
        }
    );
    $c->stash->{top_parties} = [
        map {
            { $_->get_columns }
          } $top_parties->all
    ];
}

sub default : Path {
    my ( $self, $c ) = @_;

    $c->detach('/page_not_found');
}

sub page_not_found : Private {
    my ( $self, $c ) = @_;
    $c->response->status(404);
    $c->stash->{template} = 'errors/not_found.html';
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : Private {
    my ( $self, $c ) = @_;

    return if $c->res->body;    # already have a response

    # check that we are not supposed to be producing alternative output formats
    if ( $c->output_is('json') ) {

        # get the current json_data
        my $json_result = $c->stash->{json_result} || {};

        # augment it with some extra details
        my $uri = $c->req->uri;
        $c->stash->{json_data} = {
            result  => $json_result,
            request => {
                uri    => $uri->as_string,
                path   => $uri->path,
                params => { $uri->query_form },
            },
            license => 'http://creativecommons.org/licenses/by-nc-sa/2.0/uk/',
        };

        $c->detach('View::JSON');
    }

    # check to see if this is a redirect. If it is set the template to the
    # redirect template. Also check that the location is a full url with
    # hostname.
    my $status = $c->res->status;
    if ( $status == 301 || $status == 302 ) {
        $c->stash->{template} = 'system/redirect.html';
        my $loc = $c->res->location;
        if ( $loc !~ m{ \A \w+ :// }x ) {

            my $uri = URI->new( $loc, 'http' );

            # get the query out and clear it
            my %query = $uri->query_form;
            $uri->query_form( [] );

            # create the url and reset the location
            $c->res->location( $c->uri_for( $uri->as_string, \%query ) );
        }
    }

    $c->forward('View::Web');
}

=head1 AUTHOR

Edmund von der Burg

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
