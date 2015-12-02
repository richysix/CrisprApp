package CrisprApp;
use Dancer2;
use Template;
use Data::Dumper;

use English qw( -no_match_vars );
use Readonly;

my $debug = 1;
my $test_targets;
if( $debug ){
    $test_targets = [
        {
            id => 1,
            target_name => 'test_target_1',
            gene_name => 'test_gene_1',
            gene_id => 'test_gene_id_1',
            requestor => 'test_usr1',
            ensembl_version => 'Zv9',
            status => 'REQUESTED',
            status_changed => '2015-12-02',
            crRNAs => [
                {
                    id => 1,
                    crRNA_name => 'crRNA:1:101-123:-1',
                    chr => 1,
                    start => 101,
                    end => 123,
                    strand => '-1',
                    sequence => 'GGGACATAGACATATAGACGAGG',
                },
                {
                    id => 2,
                    crRNA_name => 'crRNA:1:121-143:1',
                    chr => 1,
                    start => 121,
                    end => 143,
                    strand => '1',
                    sequence => 'GGTACGATATATATGCAACGAGG',
                }
            ]
        },
        {
            id => 2,
            target_name => 'test_target_2',
            gene_name => 'test_gene_2',
            gene_id => 'test_gene_id_2',
            requestor => 'test_usr2',
            ensembl_version => 'GRCz10',
            status => 'MISEQ_EMBRYO_SCREENING',
            status_changed => '2015-12-02',
        },
    ];
}
# else{
#     use Crispr;
#     use Crispr::Target;
#     use Crispr::Config;
#     use Crispr::DB::DBConnection;
#     use Crispr::DB::TargetAdaptor;
# }

our $VERSION = '0.1';

Readonly my $crispr_db = 'zmp_crispr_db.conf';

my $target_adaptor;
if( !$debug ){
    # connect to db
    my $DB_connection = Crispr::DB::DBConnection->new( $crispr_db );
    # get adaptors
    $target_adaptor = $DB_connection->get_adaptor( 'target' );
}

hook before_template => sub {
    my $tokens = shift;

    $tokens->{'home_url'} = uri_for('/');
    $tokens->{'targets_url'} = uri_for('/targets');
    $tokens->{'sgrnas_url'} = uri_for('/sgrnas');
    $tokens->{'primers_url'} = uri_for('/primers');
    $tokens->{'miseq_url'} = uri_for('/miseq');
};

get '/' => sub {
    template 'index', {
        template_name => 'home',
        test_text => 'This is some test text!',
    };
};

get '/targets' => sub {
    template 'targets', {
        template_name => 'targets',
        test_text => 'Target test text.',
        get_targets_url => uri_for('/get_targets'),
    };
};

get '/get_targets' => sub {
    my $targets;
    debug param('gene_name');
    if( $debug ){
        $targets = $test_targets;
    }
    else{
        $targets = $target_adaptor->fetch_all_by_gene_name( param('gene_name') );
    }
    my $err_msg = join(q{ }, "Couldn't find a match for", param('gene_name') );
    if( scalar @{$targets} == 0 ){
        template 'targets', {
            template_name => 'targets',
            err_msg => $err_msg,
            targets => $targets,
            target_url => uri_for('/target'),
        };
    }
    else{
        template 'show_targets', {
            template_name => 'show_targets',
            test_text => 'Show Targets test text.',
            targets => $targets,
            target_url => uri_for('/target'),
        };
    }
};

get '/target/:id' => sub {
    my $db_id = param('id');
    debug 'DB_ID: ', $db_id;
    my $target = $test_targets->[0];

    template 'target', {
        template_name => 'target',
        test_text => 'This is some individual target test text.',
        target => $target,
        sgrna_url => uri_for('/sgrna'),
    };
};

get '/sgrnas' => sub {
    my $crRNAs = $test_targets->[0]->{crRNAs};

    template 'sgrnas', {
        template_name => 'sgrnas',
        test_text => 'sgRNA test text.',
        crRNAs => $crRNAs,
    };
};

get '/sgrna/:id' => sub {
    my $crRNA = $test_targets->[0]->{crRNAs}->[0];
    template 'sgrna', {
        template_name => 'sgrna',
        test_text => 'This is some individual sgRNA test text.',
        crRNA => $crRNA,
    };
};

get '/primers' => sub {
    template 'primers', {
        template_name => 'primers',
        test_text => 'Primer test text.'
    };
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
