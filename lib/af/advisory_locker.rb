module Af::AdvisoryLocker
  def self.included(base)
    base.extend(ClassMethods)
  end

  def advisory_lock(&block)
    return self.class.lock_record(id, &block)
  end

  def advisory_try_lock(&block)
    return self.class.try_lock_record(id, &block)
  end

  def advisory_unlock
    self.class.unlock_record(id)
  end

  module ClassMethods
    include ::Af::Application::SafeProxy

    def advisory_locker_logger
      return logger("Af::AdvisoryLocker")
    end

    def table_oid
      if @table_oid.nil?
        sql_table_components = table_name.split('.')
        if sql_table_components.length == 1
          sql_table_components.prepend('public')
        end
        sql = <<-SQL
         SELECT
           pg_class.oid
         FROM
           pg_class,pg_namespace
         WHERE
           pg_namespace.nspname = ? AND
           pg_class.relnamespace = pg_namespace.oid AND
           pg_class.relname = ?
        SQL
        @table_oid = find_by_sql([sql, *sql_table_components]).first.oid.to_i
      end
      return @table_oid
    end

    def lock_record(id, &block)
      advisory_locker_logger.debug_fine "lock_record(#{table_oid}, #{id})"
      locked = uncached do
        find_by_sql(["select pg_advisory_lock(?, ?)", table_oid, id])[0].pg_advisory_lock == "t"
      end
      advisory_locker_logger.debug_medium "#{locked} = lock_record(#{table_oid}, #{id})"
      if block.present?
        begin
          return block.call
        ensure
          unlock_record(id)
        end
      end
      return locked
    end

    def try_lock_record(id, &block)
      advisory_locker_logger.debug_fine "try_lock_record(#{table_oid}, #{id})"
      locked = uncached do
        find_by_sql(["select pg_try_advisory_lock(?, ?)", table_oid, id])[0].pg_try_advisory_lock == "t"
      end
      advisory_locker_logger.debug_medium "#{locked} = try_lock_record(#{table_oid}, #{id})"
      if block.present?
        begin
          block.call
        ensure
          unlock_record(id)
        end
      end
      return locked
    end

    def unlock_record(id)
      advisory_locker_logger.debug_fine "unlock_record(#{table_oid}, #{id})"
      unlocked = uncached do
        find_by_sql(["select pg_advisory_unlock(?, ?)", table_oid, id])[0].pg_advisory_unlock == "t"
      end
      advisory_locker_logger.debug_medium "#{unlocked} = unlock_record(#{table_oid}, #{id})"
      return unlocked
    end
  end
end
