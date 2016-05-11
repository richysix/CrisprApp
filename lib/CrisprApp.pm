package CrisprApp;
use warnings;
use strict;

use Dancer2;
use Template;
use Data::Dumper;
use File::Spec;

use English qw( -no_match_vars );
use Readonly;
use if $ENV{ PLACK_ENV } eq 'development', 'TestMethods';

my ( $test_method_obj, $mock_objects, $test_targets, $test_pair_info,
    $test_primer_info, $test_inj_info, $test_cas9_preps, );
if( $ENV{ PLACK_ENV } eq 'development' ){
    warn "PRODUCTION\n";
    $test_method_obj = TestMethods->new();
    $mock_objects = _make_mock_objects( $test_method_obj, );
}
else{
    use Crispr;
    use Crispr::Target;
    use Crispr::Config;
    use Crispr::DB::DBConnection;
    use Crispr::DB::TargetAdaptor;
}

our $VERSION = '0.1';

Readonly my $crispr_db => defined $ENV{ DB_CONFIG } ?
        $ENV{ DB_CONFIG } :
        '/nfs/users/nfs_r/rw4/config/rw4_crispr_test.conf';

warn $crispr_db, "\n";

my ( $target_adaptor, $crRNA_adaptor, $primer_pair_adaptor, $plate_adaptor,
    $injection_pool_adaptor, $cas9_prep_adaptor, $guideRNA_adaptor,
    $plex_adaptor, $analysis_adaptor, );
if( $ENV{ PLACK_ENV } eq 'production' ){
    warn 'PRODUCTION';
    # connect to db
    my $DB_connection = Crispr::DB::DBConnection->new( $crispr_db );
    
    # get adaptors
    $target_adaptor = $DB_connection->get_adaptor( 'target' );
    $crRNA_adaptor = $DB_connection->get_adaptor( 'crRNA' );
    $primer_pair_adaptor = $DB_connection->get_adaptor( 'primer_pair' );
    $plate_adaptor = $DB_connection->get_adaptor( 'plate' );
    $injection_pool_adaptor = $DB_connection->get_adaptor( 'injection_pool' );
    $cas9_prep_adaptor = $DB_connection->get_adaptor( 'cas9_prep' );
    $guideRNA_adaptor = $DB_connection->get_adaptor( 'guidernaprep' );
    $plex_adaptor = $DB_connection->get_adaptor( 'plex' );
    $analysis_adaptor = $DB_connection->get_adaptor( 'analysis' );
}

hook before_template => sub {
    my $tokens = shift;

    $tokens->{'home_url'} = uri_for('/');
    $tokens->{'targets_url'} = uri_for('/targets');
    $tokens->{'sgrnas_url'} = uri_for('/sgrnas');
    $tokens->{'primers_url'} = uri_for('/primer_pairs');
    $tokens->{'injections_url'} = uri_for('/injections');
    $tokens->{'miseq_url'} = uri_for('/miseq');
};

get '/' => sub {
    template 'index', {
        template_name => 'home',
    };
};

get '/targets' => sub {
    template 'targets', {
        template_name => 'targets',
        get_targets_url => uri_for('/get_targets'),
    };
};

get '/get_targets' => sub {
    my $targets;
    my $target_info = param('target');
    my $requestor = param('requestor');
    my $status = param('status');
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $targets = $mock_objects->{mock_targets};
    }
    else{
        if( $target_info ){
            $targets = $target_adaptor->fetch_all_by_target_name_gene_id_gene_name( $target_info );
        }
        elsif( $requestor ){
            $targets = $target_adaptor->fetch_all_by_requestor( $requestor );
        }
        elsif( $status ){
            $targets = $target_adaptor->fetch_all_by_status( $status );
        }
    }
    my $err_msg;
    if( scalar @{$targets} == 0 ){
        $err_msg = "Couldn't find any matches for:<br>";
        $err_msg .= join(' - ', 'Target', $target_info, ) . '<br>' if $target_info;
        $err_msg .= join(' - ', 'Requestor', $requestor, ) . '<br>' if $requestor;
        $err_msg .= join(' - ', 'Status', $status, ) . '<br>' if $status;
    }
    my @targets = sort { lc($a->gene_name) cmp lc($b->gene_name) } @{$targets};

    if( $err_msg ){
        template 'targets', {
            err_msg => $err_msg,
            target_url => uri_for('/get_targets'),
        };
    }
    else{
        template 'show_targets', {
            targets => \@targets,
            target_url => uri_for('/target'),
        };
    }
};

get '/target/:target_id' => sub {
    my $db_id = param('target_id');
    debug 'DB_ID: ', $db_id;
    my $target;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $target = $mock_objects->{mock_target};
    }
    else{
        $target = $target_adaptor->fetch_by_id( param('target_id') );
        $target->crRNAs( $crRNA_adaptor->fetch_all_by_target($target) );
    }

    template 'target', {
        template_name => 'target',
        target => $target,
        sgrna_url => uri_for('/sgrna'),
    };
};

get '/sgrnas' => sub {
    template 'sgrnas', {
        template_name => 'sgrnas',
        get_sgrnas_url => uri_for('/get_sgrnas'),
    };
};

get '/get_sgrnas' => sub {
    my $plate_number = param('plate_number');
    my $well_id = param('well');
    my $crRNA_name = param('crRNA_name');
    my $target_info = param('target');
    my $requestor = param('requestor');
    my $status = param('status');
    debug join(q{ }, 'PLATE_NAME: ', $plate_number,
               'WELL: ', $well_id,
               'crRNA NAME: ', $crRNA_name,
               'TARGET: ', $target_info,
               'REQUESTOR: ', $requestor,
               'STATUS: ', $status,
              );

    my $crRNAs;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $crRNAs = $mock_objects->{crRNAs};
    }
    else{
        if( $plate_number ){
            if( $well_id ){
                my $crRNA;
                eval {
                    $crRNA = $crRNA_adaptor->fetch_by_plate_num_and_well( $plate_number, $well_id, );
                };
                $crRNAs = [ $crRNA ] if $crRNA;
            }
            else{
                eval{
                    $crRNAs = $crRNA_adaptor->fetch_by_plate_num_and_well( $plate_number, );
                };
            }
        }
        elsif( $crRNA_name ){
            eval{
                $crRNAs = $crRNA_adaptor->fetch_all_by_name( $crRNA_name, );
            };
        }
        elsif( $target_info ){
            my @crRNAs;
            my $targets = $target_adaptor->fetch_all_by_target_name_gene_id_gene_name( $target_info );
            foreach my $target ( @{$targets} ){
                my $crRNAs;
                eval{
                    $crRNAs = $crRNA_adaptor->fetch_all_by_target( $target );
                };
                push @crRNAs, @{$crRNAs};
            }
            $crRNAs = \@crRNAs;
        }
        elsif( $requestor ){
            my $targets = $target_adaptor->fetch_all_by_requestor( $requestor );
            $crRNAs = $crRNA_adaptor->fetch_all_by_targets( $targets );
        }
        elsif( $status ){
            $crRNAs = $crRNA_adaptor->fetch_all_by_status( $status );
        }
        # get targets for each crispr
        foreach my $crRNA ( @{$crRNAs} ){
            if( defined $crRNA && !defined $crRNA->target ){
                $crRNA->target( $target_adaptor->fetch_by_crRNA_id( $crRNA->crRNA_id ) );
            }
        }
    }

    my $err_msg;
    if( scalar @{$crRNAs} == 0 ){
        $err_msg = "Couldn't find any matches for:<br>";
        $err_msg .= join(' - ', 'Plate', $plate_number, ) . '<br>' if $plate_number;
        $err_msg .= join(' - ', 'Well', $well_id, ) . '<br>' if $well_id;
        $err_msg .= join(' - ', 'crRNA Name', $crRNA_name, ) . '<br>' if $crRNA_name;
        $err_msg .= join(' - ', 'Target', $target_info, ) . '<br>' if $target_info;
        $err_msg .= join(' - ', 'Requestor', $requestor, ) . '<br>' if $requestor;
        $err_msg .= join(' - ', 'Status', $status, ) . '<br>' if $status;
    }
    
    my @crRNAs = sort
        { lc($a->target->gene_name) cmp lc($b->target->gene_name) } @{$crRNAs};
    
    if( $err_msg ){
        template 'sgrnas', {
            template_name => 'sgrnas',
            err_msg => $err_msg,
            get_sgrnas_url => uri_for('/get_sgrnas'),
        };
    }
    else{
        template 'show_sgrnas', {
            template_name => 'sgrnas',
            crRNAs => \@crRNAs,
            sgrna_url => uri_for('/sgrna'),
        };
    }
};

get '/sgrna/:crRNA_id' => sub {
    my $db_id = param('crRNA_id');
    debug 'DB_ID: ', $db_id;
    my $crRNA;
    my $primer_pairs = [];
    my $primer_msg = '';
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $crRNA = $mock_objects->{crRNAs}->[$db_id-1];
        if( $db_id == 1 ){
            $primer_pairs = [ $mock_objects->{mock_primer_pair} ];
        }
    }
    else{
        $crRNA = $crRNA_adaptor->fetch_by_id( param('crRNA_id') );
        
        # retrieve primer pairs for crispr
        $primer_pairs = $primer_pair_adaptor->fetch_all_by_crRNA_id( param('crRNA_id') );
        # sort by type
        @{$primer_pairs} = sort { $a->type cmp $b->type } @{$primer_pairs};
    }
    my $primers = scalar @{$primer_pairs};
    if( $primers == 0 ){
        $primer_msg = "There are currently no screening primers in the database for this guide RNA.";
    }
    
    template 'sgrna', {
        crRNA => $crRNA,
        primer_msg => $primer_msg,
        primers => $primers,
        primer_pairs => $primer_pairs,
    };
};

get '/primer_pairs' => sub {
    template 'primer_pairs', {
        get_primers_url => uri_for('/get_primer_pairs'),
    };
};

get '/get_primer_pairs' => sub {
    my $crRNA_id = param('crRNA_id');
    my $plate_number = param('plate_number');
    my $well_id = param('well');
    my $crRNA_name = param('crRNA_name');
    my $crispr_plate = param('crispr_plate');
    my $crispr_well = param('crispr_well');

    debug $crRNA_id;

    my $pair_info = [];
    my $primer_pairs = [];
    my $crRNAs;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $primer_pairs = [ $mock_objects->{mock_primer_pair} ];
    }
    else{
        if( $crRNA_id ){
            $primer_pairs = $primer_pair_adaptor->fetch_all_by_crRNA_id( $crRNA_id );
        }
        if( $plate_number ){
            foreach my $plate_suffix ( qw{ f g h } ){
                my $plate_name = sprintf('CR_%06d%s', $plate_number, $plate_suffix, );
                if( $well_id ){
                    push @{$primer_pairs}, @{ $primer_pair_adaptor->fetch_by_plate_name_and_well( $plate_name, $well_id ) };
                }
                else{
                    push @{$primer_pairs}, @{ $primer_pair_adaptor->fetch_by_plate_name_and_well( $plate_name, $well_id ) };
                }
            }
        }
        if( $crRNA_name ){
            $crRNAs = $crRNA_adaptor->fetch_all_by_name( $crRNA_name );

        }
        if( $crispr_plate ){
            if( $crispr_well ){
                my $crRNA;
                eval {
                    $crRNA = $crRNA_adaptor->fetch_by_plate_num_and_well( $crispr_plate, $crispr_well, );
                };
                $crRNAs = [ $crRNA ] if $crRNA;
            }
            else{
                eval{
                    $crRNAs = $crRNA_adaptor->fetch_by_plate_num_and_well( $crispr_plate, );
                };
            }
        }
        if( $crRNAs ){
            $primer_pairs = $primer_pair_adaptor->fetch_all_by_crRNAs( $crRNAs );
        }
    }
    
    @{$primer_pairs} = sort {
        $a->left_primer->well->position cmp $b->left_primer->well->position ||
        $a->left_primer->well->plate->plate_name cmp $b->left_primer->well->plate->plate_name
            } @{$primer_pairs};
    
    my $primers = scalar @{$primer_pairs};
    if( $primers == 0 ){
        my $err_msg = "Couldn't find any matches for:<br>";
        $err_msg .= join(' - ', 'Plate', $plate_number, ) . '<br>' if $plate_number;
        $err_msg .= join(' - ', 'Well', $well_id, ) . '<br>' if $well_id;
        $err_msg .= join(' - ', 'crRNA Name', $crRNA_name, ) . '<br>' if $crRNA_name;
        $err_msg .= join(' - ', 'Crispr Plate', $crispr_plate, ) . '<br>' if $crispr_plate;
        $err_msg .= join(' - ', 'Crispr Well', $crispr_well, ) . '<br>' if $crispr_well;
        template 'primer_pairs', {
            get_primers_url => uri_for('/get_primer_pairs'),
            err_msg => $err_msg,
        };
    }
    else{
        template 'show_primer_pairs', {
            primers => $primers,
            primer_pairs => $primer_pairs,
        };
    }
};

get '/miseq' => sub {
    template 'miseq', {
        template_name => 'miseq',
        add_miseq_url => uri_for('add_miseq'),
        get_miseq_url => uri_for('get_miseq'),
    };
};

get '/get_miseq' => sub {
    debug "MiSeq ID: ", param('miseq_run_id');
    
    my ($plex, $err_msg, $analyses );
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $plex = $mock_objects->{mock_plex};
        $analyses = [ $mock_objects->{mock_analysis}, ];
    }
    else{
        # if the supplied value is all digits, assume it's a run id
        if( param('miseq_run_id') =~ m/\A \d+ \z/xms ){
            $plex = $plex_adaptor->fetch_by_run_id( param('miseq_run_id') );
        }
        # else assume it's a plex name
        else{
            $plex = $plex_adaptor->fetch_by_name( param('miseq_run_id') );
        }
        
        if( !$plex ){
            $err_msg = join(q{ }, "Couldn't find plex", param('miseq_run_id'),
                "in the database." ) . "\n";
        }
        else{
            # get plex results
            $analyses = $analysis_adaptor->fetch_all_by_plex( $plex );
        }
    }
    template 'miseq', {
        template_name => 'miseq',
        plex => $plex,
        analyses => $analyses,
        err_msg => $err_msg,
        injection_url => uri_for('/injection'),
        sgrna_url => uri_for('/sgrna'),
        analysis_url => uri_for('/analysis'),
    };
};

get '/analysis/:analysis_id' => sub {
    my $analysis_id = param('analysis_id');
    
    my $analysis;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $analysis = $mock_objects->{mock_analysis};
    }
    else{
        $analysis = $analysis_adaptor->fetch_by_analysis_id( $analysis_id );
    }
    
    my $seq_results;
    foreach my $sample_amplicon ( @{ $analysis->info } ){
        $seq_results = $analysis_adaptor->fetch_sequencing_results_by_analysis_id( $analysis->db_id );
    }
    
    template 'analysis_results', {
        analysis => $analysis,
        seq_results => $seq_results,
        num_samples => scalar $analysis->samples,
        
    };
};

sub get_cas9_preps {
    my $cas9_preps;
    my @cas9_preps;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $cas9_preps = [ $mock_objects->{mock_cas9_prep} ];
    }
    else{
        # get all cas9_preps from the db
        $cas9_preps = $cas9_prep_adaptor->_fetch();
    }
    foreach my $prep ( @{$cas9_preps} ){
        my $name = join(q{}, $prep->cas9->type, '(', $prep->db_id, ')' );
        push @cas9_preps, { name => $name, };
    }
    return( \@cas9_preps, );
}

get '/injections' => sub {
    my $cas9_preps = get_cas9_preps();
    template 'injections', {
        template_name => 'injections',
        cas9_preps => $cas9_preps,
        add_injection_url => uri_for('/add_injection_to_db'),
        get_injections_url => uri_for('/get_injections'),
    };
};

get '/get_injections' => sub {
    my $inj_num = param('inj_name');
    my $date = param('date');

    my $injections;
    my $err_msg;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $injections = [ $mock_objects->{mock_injection_pool},
                        $mock_objects->{mock_injection_pool}, ];
    }
    else{
        if( param('inj_name') ){
            my $injection = $injection_pool_adaptor->fetch_by_name( param('inj_name') );
            $injections = defined $injection ? [ $injection ] : [];
        }
        elsif( param('date') ){
            $injections = $injection_pool_adaptor->fetch_all_by_date( param('date') );
        }
        else{
            $injections = $injection_pool_adaptor->_fetch();
        }
    }
    
    if( scalar @{$injections} == 0 ){
        my $err_msg = "Couldn't find any matches for:<br>";
        $err_msg .= join(' - ', 'Name', param('inj_name'), ) . '<br>' if param('inj_name');
        $err_msg .= join(' - ', 'Date', param('date'), ) . '<br>' if param('date');
        my $cas9_preps = get_cas9_preps();
        template 'injections', {
            cas9_preps => $cas9_preps,
            add_injection_url => uri_for('/add_injection_to_db'),
            get_injections_url => uri_for('/get_injections'),
            err_msg => $err_msg,
        };
    }
    else{
        if( scalar @{$injections} == 1 ){
            template 'injection', {
                injection => $injections->[0],
            };
        }
        else{
            template 'show_injections', {
                injections => $injections,
                injection_url => uri_for('/injection'),
            };
        }
    }
};

get '/injection/:db_id' => sub {
    my $db_id = param('db_id');

    my $injection;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $injection = $mock_objects->{mock_injection_pool};
    }
    else{
        $injection = $injection_pool_adaptor->fetch_by_id( $db_id );
    }

    template 'injection', {
        injection => $injection,
    };
};

post '/add_injection_to_db' => sub {
    # check params
    my $gRNA_preps;
    my ( $err_msg, $success_msg );
    my $cas9_prep;
    my $cas9_preps;
    my @cas9_preps;
    my $inj_pool;
    if( $ENV{ PLACK_ENV } eq 'development' ){
        $cas9_prep = $test_cas9_preps->[0];
        #$cas9_preps = $test_cas9_preps;
        $success_msg = 'SUCCESS';
        $inj_pool = undef;
    }
    else{
        if( param('sgrnas') ){
            foreach my $crispr_plate_well ( split /,/, param('sgrnas') ){
                my $crRNA = $crRNA_adaptor->fetch_by_plate_num_and_well( split /_/, $crispr_plate_well );
                my $gRNA_preps_from_db = $guideRNA_adaptor->fetch_all_by_crRNA_id( $crRNA->crRNA_id );
                my $gRNA_prep;
                if( scalar @{ $gRNA_preps_from_db } == 0 ){
                    $err_msg = "Could not find guide RNA prep for crispr $crispr_plate_well\n";
                    last;
                }
                elsif( scalar @{ $gRNA_preps_from_db } > 1 ){
                    # sort preps by date and picked most recent one
                    $gRNA_prep = (sort { $b->date <=> $a->date } @{ $gRNA_preps_from_db })[0];
                }
                else{
                    $gRNA_prep = $gRNA_preps_from_db->[0];
                }
                $gRNA_prep->injection_concentration( param('sgrnas_conc') );
                push @{$gRNA_preps}, $gRNA_prep;
            }
        }
        if( param('cas9') ){
            param('cas9') =~ m/\( ([0-9]+) \)/xms;
            my $cas9_prep_id = $1;
            $cas9_prep = $cas9_prep_adaptor->fetch_by_id( $cas9_prep_id );
        }
        
        # make an injection object
        $inj_pool = Crispr::DB::InjectionPool->new(
            pool_name => param('inj_name'),
            cas9_prep => $cas9_prep,
            cas9_conc => param('cas9_conc'),
            date => param('date'),
            line_injected => param('line_inj'),
            line_raised => param('line_raised'),
            sorted_by => undef,
            guideRNAs => $gRNA_preps,
        );
        eval{
            $inj_pool = $injection_pool_adaptor->store( $inj_pool );
        };
        if( $EVAL_ERROR ){
            if( $EVAL_ERROR =~ m/ALREADY\sEXISTS/xms ){
                $err_msg = join(q{}, 'Injection, ',
                                $inj_pool->pool_name,
                                ', already exists in the database.',
                            );
            }
            else{
                $err_msg = 'An unexpected error occurred. ' .
                    'Please contact the database administrator.<br>' .
                    $EVAL_ERROR;
            }
        }
        else{
            $success_msg = join(q{}, 'Injection, ',
                                $inj_pool->pool_name,
                                ', was successfully added to the database.',
                            );
        }
        
        if( !$inj_pool->db_id ){
            $inj_pool = undef;
        }
        # get all cas9_preps from the db
        $cas9_preps = $cas9_prep_adaptor->_fetch();
    }
    
    warn 'SUCCESS_MSG: ', $success_msg, "\n";
    
    foreach my $prep ( @{$cas9_preps} ){
        my $name = join(q{}, $prep->cas9->type, '(', $prep->db_id, ')' );
        push @cas9_preps, { name => $name, };
    }

    template 'injections', {
        cas9_preps => \@cas9_preps,
        injection => $inj_pool,
        err_msg => $err_msg,
        success_msg => $success_msg,
        add_injection_url => uri_for('/add_injection_to_db'),
        get_injections_url => uri_for('/get_injections'),
    };
};

sub _make_mock_objects {
    my ( $test_method_obj, ) = @_;
    my $mock_objects = { add_to_db => 0 };
    
    my ( $mock_target, $mock_target_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'target', $mock_objects, );
    my ( $mock_plate, $mock_plate_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'plate', $mock_objects, );
    $mock_objects->{mock_target} = $mock_target;
    $mock_objects->{mock_targets} = [ $mock_target, ];
    $mock_objects->{crRNA_num} = 1;
    my ( $mock_crRNA_1, $mock_crRNA_1_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'crRNA', $mock_objects, );
    $mock_objects->{crRNA_num} = 2;
    my ( $mock_crRNA_2, $mock_crRNA_2_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'crRNA', $mock_objects, );
    # add target to crisprs
    $mock_crRNA_1->mock('target', sub { return $mock_target; } );
    $mock_crRNA_2->mock('target', sub { return $mock_target; } );
    $mock_objects->{crRNAs} = [ $mock_crRNA_1, $mock_crRNA_2 ];
    
    # add crispr to target
    $mock_target->mock('crRNAs', sub{ return [ $mock_crRNA_1, $mock_crRNA_2 ] } );
    
    # make mock well object and add to crispr
    $mock_objects->{mock_plate} = $mock_plate;
    my ( $mock_well_1, $mock_well_1_id, ) = $test_method_obj->create_mock_object_and_add_to_db( 'well', $mock_objects, );
    my ( $mock_well_2, $mock_well_2_id, ) = $test_method_obj->create_mock_object_and_add_to_db( 'well', $mock_objects, );
    $mock_objects->{mock_well_1} = $mock_well_1;
    $mock_objects->{mock_well_2} = $mock_well_2;
    $mock_well_2->mock('position', sub { return 'A02'; } );

    # add well to crisprs
    $mock_crRNA_1->mock('well', sub { return $mock_well_1; } );
    $mock_crRNA_2->mock('well', sub { return $mock_well_2; } );
    
    my ( $mock_plex, $mock_plex_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'plex', $mock_objects, );
    $mock_objects->{mock_plex} = $mock_plex;
    my ( $mock_cas9, $mock_cas9_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'cas9', $mock_objects, );
    $mock_objects->{mock_cas9_object} = $mock_cas9;
    my ( $mock_cas9_prep, $mock_cas9_prep_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'cas9_prep', $mock_objects, );
    $mock_objects->{mock_cas9_prep} = $mock_cas9_prep;
    $mock_objects->{mock_well} = $mock_well_1;
    $mock_objects->{mock_crRNA} = $mock_crRNA_1;
    $mock_objects->{gRNA_num} = 1;
    my ( $mock_gRNA_1, $mock_gRNA_1_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'gRNA', $mock_objects, );
    $mock_objects->{mock_crRNA} = $mock_crRNA_2;
    $mock_objects->{gRNA_num} = 2;
    my ( $mock_gRNA_2, $mock_gRNA_2_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'gRNA', $mock_objects, );
    $mock_objects->{mock_cas9_prep} = $mock_cas9_prep;
    $mock_objects->{mock_gRNA_1} = $mock_gRNA_1;
    $mock_objects->{mock_gRNA_2} = $mock_gRNA_2;
    my ( $mock_injection_pool, $mock_injection_pool_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'injection_pool', $mock_objects, );
    $mock_objects->{mock_injection_pool} = $mock_injection_pool;
    $mock_objects->{sample_ids} = [ 1..10 ];
    $mock_objects->{well_ids} = [ qw{A01 A02 A03 A04 A05 A06 A07 A08 A09 A10} ];
    my ( $mock_samples, $mock_sample_ids, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'sample', $mock_objects, );
    $mock_objects->{mock_samples} = $mock_samples;
    $mock_objects->{barcode_ids} = [ 1..10 ];
    my ( $mock_left_primer, $mock_left_primer_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'primer', $mock_objects, );
    $mock_objects->{mock_left_primer} = $mock_left_primer;
    my ( $mock_right_primer, $mock_right_primer_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'primer', $mock_objects, );
    $mock_objects->{mock_right_primer} = $mock_right_primer;
    my ( $mock_primer_pair, $mock_primer_pair_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'primer_pair', $mock_objects, );
    $mock_objects->{mock_primer_pair} = $mock_primer_pair;
    my ( $mock_sample_amplicons, $mock_sample_amplicon_ids, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'sample_amplicon', $mock_objects, );
    my ( $mock_analysis, $mock_analysis_id, ) =
        $test_method_obj->create_mock_object_and_add_to_db( 'analysis', $mock_objects, );
    $mock_objects->{mock_analysis} = $mock_analysis;
    
    warn Dumper( $mock_objects, );
    
    
    return $mock_objects;
}

1;
