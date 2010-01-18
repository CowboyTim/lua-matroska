#!/usr/bin/perl -w

use strict; use warnings;


use Data::Dumper;
use HTML::TreeBuilder;

my $p = HTML::TreeBuilder->new();
my $d = $p = $p->parse_file($ARGV[0]);


my $n = traverse($d);

$n = (($n->content())[0][1]->content())[0][0]->content();
shift @{$n};
shift @{$n};
#print Dumper($n);

my %map = (
    0 => 'name', 
    1 => 'level', 
    2 => 'id', 
    3 => 'mandatory', 
    4 => 'multi', 
    5 => 'range', 
    6 => 'default', 
    7 => 'type', 
    8 => 'description'
);

my @list;
foreach my $ebml (@{$n}){
    my @attrs = map {delete $_->{_parent} && $_->{_content}[0]} $ebml->content_list();
    my $ebmldef = {map {$map{$_},$attrs[$_]} keys %map};

    $ebmldef->{id} = uc($ebmldef->{id});
    $ebmldef->{id} =~ s/\]|\[//g;

    push @list, $ebmldef if $ebmldef->{id};
}

#print Dumper(\@list);

print "local matroska_parser_def = {}\n";

foreach my $ebml (@list){
    my $desc = join(',', map {"$_:".(defined $ebml->{$_}?$ebml->{$_}:'<nil>')} keys %{$ebml});
    my $type = lc($ebml->{type});
    $type =~ s/\W/_/g;
    $type =~ s/__/_/g;
    my $level = $ebml->{level};
    $level =~ s/\D//g;

    print 'matroska_parser_def["'.
        $ebml->{id}.'"]={_G.matroska.ebml_parse_'.$type.",'$ebml->{name}', $level} -- $desc\n";
}

print "return matroska_parser_def\n";




sub traverse {
    my ($node) = @_;
    foreach my $c (@{$node->content_array_ref()}){

        #print Dumper($c);
        if (UNIVERSAL::isa($c, 'HTML::Element')){
            #print 'id:',$c->id()||'<undef>',"\n";
            #print 'tag:',$c->tag(),"\n";
            my $class = $c->attr('class');
            if (!defined $c->id() and defined $class and $class eq 'techdef' and $c->tag() eq 'div'){
                $c->parent(undef);
                return $c;
            }
            if (my $n = traverse($c)){
                return $n
            }
        }
    }
    return undef;
}
