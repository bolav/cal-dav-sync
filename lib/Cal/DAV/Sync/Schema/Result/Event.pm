package Cal::DAV::Sync::Schema::Result::Event;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('event');
__PACKAGE__->add_columns(
  'id'   => { data_type => 'INTEGER', is_nullable => 0, is_auto_increment => 1, },
  'cid'  => { data_type => 'INTEGER', is_nullable => 0, },
  'fn'   => { data_type => 'VARCHAR', is_nullable => 0, size => 255 },
  'etag' => { data_type => 'VARCHAR', is_nullable => 0, size => 255 },
  'lastmodified' => { data_type => 'VARCHAR', is_nullable => 1, size => 255 },
  
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(calendar => 'Cal::DAV::Sync::Schema::Result::Calendar','cid');

1;