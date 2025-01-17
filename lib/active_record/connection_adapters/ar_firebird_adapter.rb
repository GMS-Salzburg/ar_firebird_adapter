require 'fb'

require 'active_record/connection_adapters/ar_firebird/connection'
require 'active_record/connection_adapters/ar_firebird/database_limits'
require 'active_record/connection_adapters/ar_firebird/database_statements'
require 'active_record/connection_adapters/ar_firebird/schema_statements'
require 'active_record/connection_adapters/ar_firebird/sql_type_metadata'
require 'active_record/connection_adapters/ar_firebird/fb_column'
require 'active_record/connection_adapters/ar_firebird/quoting'

require 'arel/visitors/ar_firebird'

class ActiveRecord::ConnectionAdapters::ArFirebirdAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter

  ADAPTER_NAME = "ArFirebird".freeze
  DEFAULT_ENCODING = "Windows-1252".freeze

  include ActiveRecord::ConnectionAdapters::ArFirebird::DatabaseLimits
  include ActiveRecord::ConnectionAdapters::ArFirebird::DatabaseStatements
  include ActiveRecord::ConnectionAdapters::ArFirebird::SchemaStatements
  include ActiveRecord::ConnectionAdapters::ArFirebird::Quoting



  @boolean_domain = { name: "smallint", limit: 1, type: "smallint", true: 1, false: 0}

  class << self
    attr_accessor :boolean_domain
  end

  NATIVE_DATABASE_TYPES =  {
    primary_key: 'integer not null primary key',
    string:      { name: 'varchar', limit: 255 },
    text:        { name: 'blob sub_type text' },
    integer:     { name: 'integer' },
    float:       { name: 'float' },
    decimal:     { name: 'decimal' },
    datetime:    { name: 'timestamp' },
    timestamp:   { name: 'timestamp' },
    date:        { name: 'date' },
    binary:      { name: 'blob' },
    boolean:     { name: ActiveRecord::ConnectionAdapters::ArFirebirdAdapter.boolean_domain[:name] }
  }

  def native_database_types
    NATIVE_DATABASE_TYPES
  end

  def arel_visitor
    @arel_visitor ||= Arel::Visitors::ArFirebird.new(self)
  end

  def prefetch_primary_key?(table_name = nil)
    true
  end

  def active?
    return false unless @connection.open?

    @connection.query("SELECT 1 FROM RDB$DATABASE")
    true
  rescue
    false
  end

  def reconnect!
    disconnect!
    @connection = ::Fb::Database.connect(@config)
  end

  def disconnect!
    super
    @connection.close rescue nil
  end

  def reset!
    reconnect!
  end

  def primary_keys(table_name)
    raise ArgumentError unless table_name.present?

    names = query_values(<<~SQL, "SCHEMA")
      SELECT
        s.rdb$field_name
      FROM
        rdb$indices i
        JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
        LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
      WHERE
        i.rdb$relation_name = '#{table_name.upcase}'
        AND c.rdb$constraint_type = 'PRIMARY KEY';
    SQL

    names.map(&:strip).map(&:downcase)
  end

  def encoding
    @connection.encoding
  end

  def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil) # :doc:
    sql = sql.encode('UTF-8', encoding) if sql.encoding.to_s == encoding
    super
  end

  def supports_foreign_keys?
    true
  end

protected

  def translate_exception(e, message)
    case e.message
    when /violation of FOREIGN KEY constraint/
      ActiveRecord::InvalidForeignKey.new(message)
    when /violation of PRIMARY or UNIQUE KEY constraint/, /attempt to store duplicate value/
      ActiveRecord::RecordNotUnique.new(message)
    when /This operation is not defined for system tables/
      ActiveRecord::ActiveRecordError.new(message)
    else
      #super
      ActiveRecord::ActiveRecordError.new(message)
    end
  end

end
