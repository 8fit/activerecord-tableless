# require 'sqlite3'
require 'active_record'
require 'activerecord-tableless'
require 'logger'
require 'spec_helper'
require 'pry'
require 'pg'

def make_tableless_model(database = nil, nested = nil)
  eval <<EOCLASS
  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql', :database => 'test')
  ActiveRecord::Base.connection.execute("drop table if exists chairs")
  ActiveRecord::Base.connection.execute("create table chairs (id INTEGER PRIMARY KEY, name TEXT )")

  class Chair < ActiveRecord::Base
    #{database ? "has_no_table :database => :#{database}" : 'has_no_table'}
    column :id, :integer
    column :name, :string
    #{if nested
      '
      has_many :arm_rests
      accepts_nested_attributes_for :arm_rests
      '
      end}
  end
EOCLASS
  if nested
  eval <<EOCLASS
    class ArmRest < ActiveRecord::Base
      #{database ? "has_no_table :database => :#{database}" : 'has_no_table'}
      belongs_to :chair
      column :id, :integer
      column :chair_id, :integer
      column :name, :string
      column :json_array, :string
    end
EOCLASS
  end
end

def remove_models
  Object.send(:remove_const, :Chair) rescue nil
  Object.send(:remove_const, :ArmRest) rescue nil
  ActiveRecord::Base.clear_all_connections!
end

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::Severity::UNKNOWN

shared_examples_for "an active record instance" do
  it { should respond_to :id }
  it { should respond_to :id= }
  it { should respond_to :name }
  it { should respond_to :name= }
  it { should respond_to :update_attributes }
  describe "#attributes=" do
    before(:example){ subject.attributes=({:name => 'Jarl Friis'}) }
    it "assign attributes" do
      expect(subject.name).to eq 'Jarl Friis'
    end
  end
end

shared_examples_for "a nested active record" do
  describe "conllection#build" do
    specify do
      expect(subject.arm_rests.build({:name => 'nice arm_rest'})).to be_an_instance_of(ArmRest)
    end
  end
  describe "conllection#<<" do
    specify do
      expect(subject.arm_rests << ArmRest.new({:name => 'nice arm_rest'})).to have(1).items
    end
    describe 'appending two children' do
      before(:example) do
        subject.arm_rests << [ArmRest.new({:name => 'left'}),
                              ArmRest.new({:name => 'right'})]
      end
      it "assigns nested attributes" do
        expect(subject.arm_rests[0].name).to eq 'left'
        expect(subject.arm_rests[1].name).to eq 'right'
      end
    end
  end
  describe "#attributes=" do
    before(:example){ subject.attributes=({ :name => 'Jarl Friis',
                                            :arm_rests_attributes => [
                                                                      {:name => 'left'},
                                                                      {:name => 'right'}
                                                                     ]
                                          }) }
    it "assigns attributes" do
      expect(subject.name).to eq 'Jarl Friis'
    end
    it "assigns nested attributes" do
      expect(subject.arm_rests[0].name).to eq 'left'
      expect(subject.arm_rests[1].name).to eq 'right'
    end
  end
end

shared_examples_for "a tableless model with fail_fast" do
  case ActiveRecord::VERSION::MAJOR
  when 2
    describe "#find" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect { subject.find(1) }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
      end
    end
    describe "#find(:all)" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect { subject.find(:all) }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
      end
    end
  when 3
    describe "#all" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect { subject.all }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
      end
    end
  when 4
    describe "#all" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect { subject.all }.to_not raise_exception
      end
    end
    describe "#all[]" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect { subject.all[0] }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
      end
    end
  end
  describe "#create" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.create(:name => 'Jarl') }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
  describe "#destroy" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.destroy(1) }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
  describe "#destroy_all" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.destroy_all }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
end

shared_examples_for "a tableless model instance with fail_fast" do
  it_behaves_like "an active record instance"
  describe "#save" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.save }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
  describe "#save!" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.save! }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
  describe "#reload" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.reload }.to raise_exception(ActiveRecord::Tableless::NoDatabase)
    end
  end
  describe "#update_attributes" do
    it "raises ActiveRecord::Tableless::NoDatabase" do
      expect { subject.update_attributes(:name => 'Jarl') }.to raise_exception(StandardError)
    end
  end
end

describe "Tableless model with fail_fast" do
  before(:context) {make_tableless_model(nil, nil)}
  after(:context){ remove_models }
  subject { Chair }
  it_behaves_like "a tableless model with fail_fast"
  describe "instance" do
    subject { Chair.new(:name => 'Jarl') }
    it_behaves_like "a tableless model instance with fail_fast"
  end
end

describe "Tableless nested with fail_fast" do
  before(:context) {make_tableless_model(nil, true)}
  after(:context){ remove_models }
  subject { Chair }
  it_behaves_like "a tableless model with fail_fast"
  describe "#new" do
    it "accepts attributes" do
      expect(subject.new(:name => "Jarl")).to be_an_instance_of(subject)
    end
    it "assign attributes" do
      expect(subject.new(:name => "Jarl").name).to eq "Jarl"
    end
  end
  describe "instance" do
    subject { Chair.new(:name => 'Jarl') }
    it_behaves_like "a tableless model instance with fail_fast"
    it_behaves_like "a nested active record"
    describe "#update_attributes" do
      it "raises ActiveRecord::Tableless::NoDatabase" do
        expect do
          subject.update_attributes(:arm_rests => {:name => 'nice arm_rest'})
        end.to raise_exception(StandardError)
      end
    end
  end
  describe "instance with nested models" do
    subject do
      Chair.new(:name => "Jarl",
                :arm_rests => [
                               ArmRest.new(:name => 'left'),
                               ArmRest.new(:name => 'right'),
                              ])
    end
    it {should be_an_instance_of(Chair) }
    it {should have(2).arm_rests }
  end
  describe "instance with nested attributes" do
    subject do
      Chair.new(:name => "Jarl",
                :arm_rests_attributes => [
                                          {:name => 'left'},
                                          {:name => 'right'},
                                         ])
    end
    it {should be_an_instance_of(Chair)}
    it {should have(2).arm_rests }
  end
end

##
## Succeeding database
##
shared_examples_for "a model with succeeding database" do
  case ActiveRecord::VERSION::MAJOR
  when 2
    describe "#find" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { subject.find(314) }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
    describe "#find(:all)" do
      specify { expect(subject.find(:all)).to eq []}
    end
  when 3, 4
    describe "#all" do
      specify { expect(subject.all).to eq []}
    end
  end
  describe "#create" do
    specify { expect(subject.create(:name => 'Jarl')).to be_an_instance_of(subject) }
  end
  describe "#destroy" do
    specify { expect(subject.destroy(1)).to be_an_instance_of(subject) }
  end
  describe "#destroy_all" do
    specify { expect(subject.destroy_all).to eq [] }
  end
end

shared_examples_for "an instance with succeeding database" do
  it_behaves_like "an active record instance"

  describe "#save" do
    specify { expect(subject.save).to eq true }
  end
  describe "#save!" do
    specify { expect(subject.save!).to eq true }
  end
  describe "#reload" do
    before { subject.save! }
    specify { expect(subject.reload).to eq subject }
  end
  describe "#update_attributes" do
    specify { expect(subject.update_attributes(:name => 'Jarl Friis')).to eq true }
  end
end

describe "ActiveRecord with real database" do
  ##This is only here to ensure that the shared examples are actually behaving like a real database.
  before(:context) do
    FileUtils.mkdir_p "tmp"
    ActiveRecord::Base.establish_connection(:adapter  => 'sqlite3', :database => 'tmp/test.db')
    ActiveRecord::Base.connection.execute("drop table if exists chairs")
    ActiveRecord::Base.connection.execute("create table chairs (id INTEGER PRIMARY KEY, name TEXT )")

    class Chair < ActiveRecord::Base
    end
  end
  after(:context) do
    remove_models
    ActiveRecord::Base.clear_all_connections!
  end

  subject { Chair }
  it_behaves_like "a model with succeeding database"
  describe "instance" do
    subject { Chair.new(:name => 'Jarl') }
    it_behaves_like "an instance with succeeding database"
  end
end

describe "Tableless model with succeeding database" do
  before(:context) { make_tableless_model(:pretend_success, nil) }
  after(:context){ remove_models }
  subject { Chair }
  it_behaves_like "a model with succeeding database"
  describe "instance" do
    subject { Chair.new(:name => 'Jarl') }
    it_behaves_like "an instance with succeeding database"
  end
end
