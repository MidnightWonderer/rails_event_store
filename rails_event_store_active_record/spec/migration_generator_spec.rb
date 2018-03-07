require 'spec_helper'
require 'pp'
require 'fakefs/safe'

module RailsEventStoreActiveRecord
  RSpec.describe MigrationGenerator do
    around(:each) do |example|
      current_stdout = $stdout
      $stdout = StringIO.new
      example.call
      $stdout = current_stdout
    end

    specify do
      FakeFS.with_fresh do
        FakeFS::FileSystem.clone(File.expand_path('../../', __FILE__))
        stub_const("ActiveRecord::VERSION::STRING", "4.2.8")

        generator = MigrationGenerator.new
        allow(Time).to receive(:now).and_return(Time.new(2016,8,9,22,22,22))
        generator.create_migration

        expect(File.read("db/migrate/20160809222222_create_event_store_events.rb")).to match(/ActiveRecord::Migration$/)
      end
    end

    specify do
      FakeFS.with_fresh do
        FakeFS::FileSystem.clone(File.expand_path('../../', __FILE__))
        stub_const("ActiveRecord::VERSION::STRING", "5.0.0")

        generator = MigrationGenerator.new
        allow(Time).to receive(:now).and_return(Time.new(2016,8,9,22,22,22))
        generator.create_migration

        active_record_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
        quoted_active_record_version = Regexp.escape(active_record_version.to_s.sub(/\A(\d+\.\d+)\.\d+\z/, '\1'))
        expect(File.read("db/migrate/20160809222222_create_event_store_events.rb")).to match(/ActiveRecord::Migration\[#{quoted_active_record_version}]$/)
      end
    end
  end
end
