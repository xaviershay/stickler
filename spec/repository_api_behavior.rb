
shared_examples_for "includes Repository::Api" do
  describe "responds to all the api methods" do
    Stickler::Repository::Api.api_methods.each do |method|
      it "responds to ##{method}" do
        @repo.respond_to?( method ).should == true
      end
    end
  end
end

require 'digest/sha1'
shared_examples_for "implements Repository::Api" do
  before( :each ) do
    @foo_gem_local_path = File.join( @gems_dir, "foo-1.0.0.gem" )
    @foo_spec = Stickler::SpecLite.new( 'foo', '1.0.0' )
    @foo_digest = Digest::SHA1.hexdigest( IO.read( @foo_gem_local_path ) )
    @missing_spec = Stickler::SpecLite.new( "does_not_exist", "0.1.0" )
  end

  %w[ uri gems_uri specifications_uri ].each do |method|
    it "returns a URI like object from #{method}" do
      result = @repo.send( method )
      [ ::URI, ::Addressable::URI ].include?( result.class ).should == true
    end
  end

  %w[ gem specification ].each do |thing|
    describe "#uri_for_#{thing}" do
      before( :each ) do
        @repo.push( @foo_gem_local_path )
        @method = "uri_for_#{thing}"
      end

      it "returns URI for a #{thing} that exists" do
        uri = @repo.send( @method, @foo_spec )
        [ ::URI, ::Addressable::URI ].include?( uri.class ).should == true
      end
      
      it "returns nil for a #{thing} that does not exist" do
        @repo.send( @method, @missing_spec ).should be_nil
      end
    end
  end
  
  it "returns a Gem::SourceIndex for #source_index" do
    idx = @repo.source_index
    idx.should be_kind_of( Gem::SourceIndex )
  end

  describe "#push" do
    it "pushes a gem from a .gem file" do
      @repo.push( @foo_gem_local_path )
      @repo.search_for( Stickler::SpecLite.new( "foo", "1.0.0" ) )
    end

    it "raises an error when pushing a gem if the gem already exists" do
      @repo.push( @foo_gem_local_path )
      lambda { @repo.push( @foo_gem_local_path ) }.should raise_error( Stickler::Repository::Error, /gem foo-1.0.0 already exists/ )
    end
  end

  describe "#delete" do
    it "deletes a gem from the repo" do
      @repo.search_for( @foo_spec ).should be_empty
      @repo.push( @foo_gem_local_path )
      @repo.search_for( @foo_spec ).size.should == 1
      @repo.delete( @foo_spec ).should == true
      @repo.search_for( @foo_spec ).should be_empty
    end

    it "returns false if it is unable to delete a gem from the repo" do
      @repo.search_for( @foo_spec ).should be_empty
      @repo.delete( @foo_spec ).should == false
    end
  end

  describe "#yank" do
    before( :each ) do
      @repo.search_for( @foo_spec ).should be_empty
      @repo.push( @foo_gem_local_path )
      @response_uri = @repo.yank( @foo_spec )
    end

    it "returns the uri in which to get the gem" do
      [ ::URI, ::Addressable::URI ].include?( @response_uri.class ).should == true
    end

    it "returns nil if the gem to yank does not exist or is already yanked" do
      @repo.yank( @missing_spec ).should == nil
    end

    it "does not find the gem in a search" do
      @repo.search_for( @foo_spec ).should be_empty
    end

    it "does not have the #uri_for_specification" do
      @repo.uri_for_specification( @foo_spec ).should be_nil
    end

    it "does have the #uri_for_gem" do
      @repo.uri_for_gem( @foo_spec ).should == @response_uri
    end

    it "can still return the gem" do
      data = @repo.get( @foo_spec )
      sha1 = Digest::SHA1.hexdigest( data )
      sha1.should == @foo_digest
    end

  end

  describe "#search_for" do
    it "returns specs for items that are found" do
      @repo.push( @foo_gem_local_path )
      @repo.search_for( @foo_spec ).should_not be_empty
    end

    it "returns an empty array when nothing is found" do
      @repo.search_for( @missing_spec ).should be_empty
    end
  end

  describe "#get" do
    it "returns the bytes of the gem for a gem that exists" do
      @repo.push( @foo_gem_local_path )
      data = @repo.get( @foo_spec )
      sha1 = Digest::SHA1.hexdigest( data )
      sha1.should == @foo_digest
    end
    
    it "returns nil if the gem does not exist" do
      @repo.get( @missing_spec ).should be_nil
    end
  end

  describe "#add" do
    it "adds a new gem via an input stream" do
      @repo.search_for( @foo_spec ).should be_empty

      opts = { :name => @foo_spec.name, :version => @foo_spec.version.to_s }
      File.open( @foo_gem_local_path ) do |f|
        opts[:body] = f
        @repo.add( opts )
      end

      @repo.search_for( @foo_spec ).size.should == 1
    end
  end

  describe "#open" do
    it "reads a gem via an output stream" do
      @repo.push( @foo_gem_local_path )
      io = @repo.open( @foo_spec )
      sha1 = Digest::SHA1.hexdigest( io.read )
      sha1.should == @foo_digest
    end

  end

end
