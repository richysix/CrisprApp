package CrisprApp;
use Dancer2;
use Template;
use Data::Dumper;

use English qw( -no_match_vars );
use Readonly;

my $debug = 1;
my ( $test_targets, $test_pair_info, );
if( $debug ){
    $test_targets = [
        {
            target_id => 1,
            target_name => 'test_target_1',
            gene_name => 'test_gene_1',
            gene_id => 'test_gene_id_1',
            requestor => 'test_usr1',
            ensembl_version => 'Zv9',
            status => 'PASSED_EMBRYO_SCREENING',
            status_changed => '2015-12-02',
            crRNAs => [
                {
                    crRNA_id => 1,
                    name => 'crRNA:1:101-123:-1',
                    sequence => 'GGGACATAGACATATAGACGAGG',
                    status => 'FAILED_EMBRYO_SCREENING',
                    status_changed => '2015-12-02',
                },
                {
                    crRNA_id => 2,
                    name => 'crRNA:1:121-143:1',
                    sequence => 'GGTACGATATATATGCAACGAGG',
                    status => 'PASSED_EMBRYO_SCREENING',
                    status_changed => '2015-12-02',
                }
            ]
        },
        {
            target_id => 2,
            target_name => 'test_target_2',
            gene_name => 'test_gene_2',
            gene_id => 'test_gene_id_2',
            requestor => 'test_usr2',
            ensembl_version => 'GRCz10',
            status => 'REQUESTED',
            status_changed => '2015-12-02',
        },
    ];
    
    $test_pair_info = [
        {
            pair_name => '19:10678178-10679198:1',
            primer_pair_id => 1,
            left_primer => {
                sequence => 'ACGATAGCATATAGACGAATAGG',
                plate_name => 'CR_000026h',
                well_id => 'A01',
            },
            right_primer => {
                sequence => 'TGATGAGCATACTGCACGATATTAG',
                plate_name => 'CR_000026h',
                well_id => 'A01',
            },
        },
        {
            pair_name => '25:1-250:1',
            primer_pair_id => 2,
            left_primer => {
                sequence => 'GACGATGACGATAGATGACGA',
                plate_name => 'CR_000026h',
                well_id => 'B01',
            },
            right_primer => {
                sequence => 'TGATGAGCATACTGCACGATATTAG',
                plate_name => 'CR_000026h',
                well_id => 'B01',
            },
        },
    ];
}
else{
    use Crispr;
    use Crispr::Target;
    use Crispr::Config;
    use Crispr::DB::DBConnection;
    use Crispr::DB::TargetAdaptor;
}

our $VERSION = '0.1';

Readonly my $crispr_db => '/nfs/users/nfs_r/rw4/config/rw4_crispr_test.conf';

my ( $target_adaptor, $crRNA_adaptor, $primer_pair_adaptor, $plate_adaptor );
if( !$debug ){
    # connect to db
    my $DB_connection = Crispr::DB::DBConnection->new( $crispr_db );
    # get adaptors
    $target_adaptor = $DB_connection->get_adaptor( 'target' );
    $crRNA_adaptor = $DB_connection->get_adaptor( 'crRNA' );
    $primer_pair_adaptor = $DB_connection->get_adaptor( 'primer_pair' );
    $plate_adaptor = $DB_connection->get_adaptor( 'plate' );
}

hook before_template => sub {
    my $tokens = shift;

    $tokens->{'home_url'} = uri_for('/');
    $tokens->{'targets_url'} = uri_for('/targets');
    $tokens->{'sgrnas_url'} = uri_for('/sgrnas');
    $tokens->{'primers_url'} = uri_for('/primer_pairs');
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
    if( $debug ){
        $targets = $test_targets;
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
    
    if( $err_msg ){
        template 'targets', {
            err_msg => $err_msg,
            target_url => uri_for('/get_targets'),
        };
    }
    else{
        template 'show_targets', {
            targets => $targets,
            target_url => uri_for('/target'),
        };        
    }
};

get '/target/:target_id' => sub {
    my $db_id = param('target_id');
    debug 'DB_ID: ', $db_id;
    my $target;
    if( $debug ){
        $target = $test_targets->[$db_id-1];
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
    
    if( $debug ){
        $crRNAs = $test_targets->[0]->{crRNAs};
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
            crRNAs => $crRNAs,
            sgrna_url => uri_for('/sgrna'),
        };
    }
};

get '/sgrna/:crRNA_id' => sub {
    my $db_id = param('crRNA_id');
    debug 'DB_ID: ', $db_id;
    my $crRNA;
    if( $debug ){
        $crRNA = $test_targets->[0]->{crRNAs}->[$db_id-1];
    }
    else{
        $crRNA = $crRNA_adaptor->fetch_by_id( param('crRNA_id') );
    }
    template 'sgrna', {
        crRNA => $crRNA,
        get_primers_url => uri_for('/get_primer_pairs'),
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
    my $err_msg;
    my $crRNAs;
    if( $debug ){
        $pair_info = $test_pair_info;
    }
    else{
        if( $crRNA_id ){
            $primer_pairs = $primer_pair_adaptor->fetch_all_by_crRNA_id( $crRNA_id );
        }
        if( $plate_number ){
            my $plate_name = sprintf('CR_%06df', $plate_number, );
            if( $well_id ){
                $primer_pairs = $primer_pair_adaptor->fetch_by_plate_name_and_well( $plate_name, $well_id );
            }
            else{
                $primer_pairs = $primer_pair_adaptor->fetch_by_plate_name_and_well( $plate_name );
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
        
        my %plate_for;
        if( scalar @{$primer_pairs} == 0 ){
            $err_msg = "Couldn't find any matches for:<br>";
            $err_msg .= join(' - ', 'Plate', $plate_number, ) . '<br>' if $plate_number;
            $err_msg .= join(' - ', 'Well', $well_id, ) . '<br>' if $well_id;
            $err_msg .= join(' - ', 'crRNA Name', $crRNA_name, ) . '<br>' if $crRNA_name;
            $err_msg .= join(' - ', 'Crispr Plate', $crispr_plate, ) . '<br>' if $crispr_plate;
            $err_msg .= join(' - ', 'Crispr Well', $crispr_well, ) . '<br>' if $crispr_well;
        }
        else{
            foreach my $primer_pair ( @{$primer_pairs} ){
                my $info = {
                    pair_name => $primer_pair->pair_name,
                    primer_pair_id => $primer_pair->primer_pair_id,
                };
                my $plate;
                if( !exists $plate_for{ $primer_pair->left_primer->plate_id } ){
                    $plate = $plate_adaptor->fetch_empty_plate_by_id( $primer_pair->left_primer->plate_id );
                    $plate_for{ $primer_pair->left_primer->plate_id } = $plate;
                }
                else{
                    $plate = $plate_for{ $primer_pair->left_primer->plate_id };
                }
                $info->{'left_primer'} = {
                        sequence => $primer_pair->left_primer->sequence,
                        plate_name => $plate->plate_name,
                        well_id => $primer_pair->left_primer->well_id,
                    };
                
                if( !exists $plate_for{ $primer_pair->right_primer->plate_id } ){
                    $plate = $plate_adaptor->fetch_empty_plate_by_id( $primer_pair->right_primer->plate_id );
                    $plate_for{ $primer_pair->right_primer->plate_id } = $plate;
                }
                else{
                    $plate = $plate_for{ $primer_pair->right_primer->plate_id };
                }
                $info->{'right_primer'} = {
                        sequence => $primer_pair->right_primer->sequence,
                        plate_name => $plate->plate_name,
                        well_id => $primer_pair->right_primer->well_id,
                    };
                
                push @{$pair_info}, $info;
            }
        }
    }
    
    if( $err_msg ){
        template 'primer_pairs', {
            err_msg => $err_msg,
            target_url => uri_for('/get_primer_pairs'),
        };
    }
    else{
        template 'show_primer_pairs', {
            pair_info => $pair_info,
        };        
    }
};

get '/miseq' => sub {
    template 'miseq', {
        template_name => 'miseq',
        test_text => 'This is some different test text!',
        add_miseq_url => uri_for('add_miseq'),
        get_miseq_url => uri_for('get_miseq'),
    };
};

get '/get_miseq' => sub {
    debug "MiSeq ID: ", param('miseq_id');
    # # my $plex;
    # eval{
    #     $plex = $plex_adaptor->fetch_by_name( param('miseq_id') );
    # }
    my $plex_from_db = {
        db_id => 1,
        plex_name => 'miseq29',
        run_id => 18627,
        analysis_started => '2015-11-26',
        analysis_finished => undef,
    };
    my ($plex, $err_msg );
    if( $plex_from_db->{plex_name} eq param('miseq_id') ){
        $plex = $plex_from_db;
        $err_msg = undef;

    }
    else{
        $plex = undef;
        $err_msg = join(q{ }, "Couldn't find plex", param('miseq_id'),
            "in the database. Do you want to try again?" ) . "\n";
    }
    template 'get_miseq', {
        template_name => 'get_miseq',
        test_text => 'This is some different test text for a retrieved MiSeq run!',
        plex => $plex,
        err_msg => $err_msg,
    };
};

1;
