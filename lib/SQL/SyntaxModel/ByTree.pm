=head1 NAME

SQL::SyntaxModel::ByTree - Build SQL::SyntaxModels from multi-dimensional Perl hashes and arrays

=cut

######################################################################

package SQL::SyntaxModel::ByTree;
use 5.006;
use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.14';

use Locale::KeyedText 0.04;
use SQL::SyntaxModel 0.22;

use base qw( SQL::SyntaxModel );

######################################################################

=head1 DEPENDENCIES

Perl Version: 5.006

Standard Modules: I<none>

Nonstandard Modules: 

	Locale::KeyedText 0.04 (for error messages)
	SQL::SyntaxModel 0.22 (parent class)

=head1 COPYRIGHT AND LICENSE

This module is Copyright (c) 1999-2004, Darren R. Duncan.  All rights reserved.
Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>, or
visit "http://www.DarrenDuncan.net" for more information.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl 5.8 itself.

Any versions of this module that you modify and distribute must carry prominent
notices stating that you changed the files and the date of any changes, in
addition to preserving this original copyright notice and other credits.  This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

######################################################################
######################################################################

# These named arguments are used with the create_[/child_]node_tree[/s]() methods:
my $ARG_NODE_TYPE = 'NODE_TYPE'; # str - what type of Node we are
my $ARG_ATTRS     = 'ATTRS'; # hash - our attributes, including refs/ids of parents we will have
my $ARG_CHILDREN  = 'CHILDREN'; # list of refs to new Nodes we will become primary parent of

######################################################################
# Overload these wrapper methods of parent so created objects blessed into subclasses.

sub new_container {
	return( SQL::SyntaxModel::ByTree::Container->new() );
}

sub new_node {
	return( SQL::SyntaxModel::ByTree::Node->new( $_[1] ) );
}

######################################################################
######################################################################

package SQL::SyntaxModel::ByTree::Container;
#use base qw( SQL::SyntaxModel::ByTree SQL::SyntaxModel::Container );
use vars qw( @ISA );
@ISA = qw( SQL::SyntaxModel::ByTree SQL::SyntaxModel::Container );

######################################################################

sub create_node_tree {
	my ($container, $args) = @_;
	defined( $args ) or $container->_throw_error_message( 'SSMBTR_C_CR_NODE_TREE_NO_ARGS' );

	unless( ref($args) eq 'HASH' ) {
		$container->_throw_error_message( 'SSMBTR_C_CR_NODE_TREE_BAD_ARGS', { 'ARG' => $args } );
	}

	my $node = $container->new_node( $args->{$ARG_NODE_TYPE} );
	$node->set_attributes( $args->{$ARG_ATTRS} ); # handles node id and all attribute types
	$node->put_in_container( $container );
	$node->add_reciprocal_links();
	$node->test_mandatory_attributes();
	$node->create_child_node_trees( $args->{$ARG_CHILDREN} );

	return( $node );
}

sub create_node_trees {
	my ($container, $list) = @_;
	$list or return( undef );
	unless( ref($list) eq 'ARRAY' ) {
		$list = [ $list ];
	}
	foreach my $element (@{$list}) {
		$container->create_node_tree( $element );
	}
}

######################################################################
######################################################################

package SQL::SyntaxModel::ByTree::Node;
#use base qw( SQL::SyntaxModel::ByTree SQL::SyntaxModel::Node );
use vars qw( @ISA );
@ISA = qw( SQL::SyntaxModel::ByTree SQL::SyntaxModel::Node );

######################################################################

sub create_child_node_tree {
	my ($node, $args) = @_;
	defined( $args ) or $node->_throw_error_message( 'SSMBTR_N_CR_NODE_TREE_NO_ARGS' );

	unless( ref($args) eq 'HASH' ) {
		$node->_throw_error_message( 'SSMBTR_N_CR_NODE_TREE_BAD_ARGS', { 'ARG' => $args } );
	}

	my $new_child = $node->new_node( $args->{$ARG_NODE_TYPE} );
	$new_child->set_attributes( $args->{$ARG_ATTRS} ); # handles node id and all attribute types
	$new_child->put_in_container( $node->get_container() );
	$new_child->add_reciprocal_links();

	$node->add_child_node( $new_child ); # sets more attributes in new_child

	$new_child->test_mandatory_attributes();
	$new_child->create_child_node_trees( $args->{$ARG_CHILDREN} );

	return( $new_child );
}

sub create_child_node_trees {
	my ($node, $list) = @_;
	$list or return( undef );
	unless( ref($list) eq 'ARRAY' ) {
		$list = [ $list ];
	}
	foreach my $element (@{$list}) {
		if( ref($element) eq ref($node) ) {
			$node->add_child_node( $element ); # will die if not same Container
		} else {
			$node->create_child_node_tree( $element );
		}
	}
}

######################################################################
######################################################################

1;
__END__

=head1 SYNOPSIS

See the code inside the test script/module files that come with this module,
't/SQL_SyntaxModel_ByTree.t' and 'lib/t_SQL_SyntaxModel_ByTree.pm'.  That code
demonstrates input that can be provided to SQL::SyntaxModel::ByTree, along with
a way to debug the result; it is a contrived example since the class normally
wouldn't get used this way.  Such samples will not be shown in this POD to save
on redundancy.

=head1 DESCRIPTION

The SQL::SyntaxModel::ByTree Perl 5 module is a completely optional
extension to SQL::SyntaxModel, and is implemented as a sub-class of that
module.  This module adds a set of new public methods which you can use to make
some tasks involving SQL::SyntaxModel less labour-intensive, depending on how
you like to use the module.  

This module is fully parent-compatible.  It does not override any parent class
methods or otherwise change how it works; if you use only methods defined in
the parent class, this module will behave identically.  All of the added
methods are wrappers over existing parent class methods, and this module does
not define any new properties.

This module's added feature, which is its name-sake, is that you can create
a Node, set all of its attributes, put it in a Container, and likewise
recursively create all of its child Nodes, all with a single method call.  In
the context of this module, the set of Nodes consisting of one starting Node
and all of its "descendants" is called a "tree".  You can create a tree of
Nodes in mainly two contexts; one context will assign the starting Node of the
new tree as a child of an already existing Node; the other will not attach the
tree to an existing Node.

=head1 CONTAINER OBJECT METHODS

=head2 create_node_tree( { NODE_TYPE[, ATTRS][, CHILDREN] } )

	my $node = $model->create_node_tree( 
		{ 'NODE_TYPE' => 'catalog', 'ATTRS' => { 'id' => 1, } } ); 

This "setter" method creates a new Node object within the context of the
current Container and returns it.  It takes a hash ref containing up to 3 named
arguments: NODE_TYPE, ATTRS, CHILDREN.  The first argument, NODE_TYPE, is a
string (enum) which specifies the Node Type of the new Node.  The second
(optional) argument, ATTRS, is a hash ref whose elements will go in the various
"attributes" properties of the new Node (and the "node id" property if
applicable).  Any attributes which will refer to another Node can be passed in
as either a Node object reference or an integer which matches the 'id'
attribute of an already created Node.  The third (optional) argument, CHILDREN,
is an array ref whose elements will also be recursively made into new Nodes,
for which their primary parent is the Node you have just made here.  Elements
in CHILDREN are always processed after the other arguments. If the root Node
you are about to make should have a primary parent Node, then you would be
better to use said parent's create_child_node_tree[/s] method instead of this
one.  This method is actually a "wrapper" for a set of other, simpler
function/method calls that you could call directly instead if you wanted more
control over the process.

=head2 create_node_trees( LIST )

	$model->create_nodes( [{ ... }, { ... }] );
	$model->create_nodes( { ... } );

This "setter" method takes an array ref in its single LIST argument, and calls
create_node_tree() for each element found in it.

=head1 NODE OBJECT METHODS

=head2 create_child_node_tree( { NODE_TYPE[, ATTRS][, CHILDREN] } )

	my $new_child = $node->add_child_node( 
		{ 'NODE_TYPE' => 'schema', 'ATTRS' => { 'id' => 1, } } ); 

This "setter" method will create a new Node, following the same semantics (and
taking the same arguments) as the Container->create_node_tree(), except that 
create_child_node_tree() will also set the primary parent of the new Node to 
be the current Node.  This method also returns the new child Node.

=head2 create_child_node_trees( LIST )

	$model->create_child_node_tree( [$child1,$child2] );
	$model->create_child_node_tree( $child );

This "setter" method takes an array ref in its single LIST argument, and calls
create_child_node_tree() for each element found in it.

=head1 BUGS

See the BUGS main documentation section of SQL::SyntaxModel since everything
said there applies to this module also.

The "use base ..." pragma doesn't seem to work properly (with Perl 5.6 at
least) when I want to inherit from multiple classes, with some required parent
class methods not being seen; I had to use the analagous "use vars @ISA; @ISA =
..." syntax instead.

=head1 CAVEATS

See the CAVEATS main documentation section of SQL::SyntaxModel since everything
said there applies to this module also.

See the TODO file for an important message concerning the future of this module.

=head1 SEE ALSO

SQL::SyntaxModel::ByTree::L::*, SQL::SyntaxModel, and other items in its SEE
ALSO documentation.

=cut
