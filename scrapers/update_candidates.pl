#!/usr/bin/env perl

use strict;
use warnings;

use YourNextMP::Schema::YourNextMPDB;

my $candidate_rs = YourNextMP::Schema::YourNextMPDB->resultset('Candidate');
my $party_rs     = YourNextMP::Schema::YourNextMPDB->resultset('Party');

# Scrape all the parties to make sure that the lists are up-to-date
foreach my $party ( $party_rs->all ) {
    printf "Scraping candidate list from %s\n", $party->name;
    $party->scrape_candidates;
}

print "\n\n";

# get all the candidates that need scraping
my $to_scrape =
  $candidate_rs->search( { scrape_source => { like => 'http://%' } } );

while ( my $candidate = $to_scrape->next ) {
    printf "Scraping %s (%s)...\n", $candidate->name, $candidate->party->name;

    $candidate->update_by_scraping;
}