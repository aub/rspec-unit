require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe RSpec::Core::ExampleGroup do
  it "supports using assertions in examples" do
    lambda {assert_equal 1, 1}.should_not raise_error
  end
end

describe "RSpec::Unit::TestCase" do
  before do
    @foo = Class.new(RSpec::Unit::TestCase)
    @foo_definition_line = __LINE__ - 1
    @caller_at_foo_definition = caller
    @formatter = RSpec::Core::Formatters::BaseFormatter.new('')
  end
  
  describe "identifying test methods" do
    it "ignores methods that don't begin with 'test_'" do
      @foo.class_eval do
        def bar; end
      end
      @foo.examples.should be_empty
    end
  
    it "notices methods that begin with 'test_'" do
      @foo.class_eval do
        def test_bar; end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'test_bar'
    end
  
    it "ignores non-public test methods" do
      @foo.class_eval do
        protected
        def test_foo; end
        private       
        def test_bar; end
      end
      @foo.examples.should be_empty
    end
  
    it "ignores methods with good names but requiring parameters" do
      @foo.class_eval do
        def test_foo(a); end
        def test_bar(a, *b); end
      end
      @foo.examples.should be_empty
    end
    
    it "notices methods that have only optional parameters" do
      @foo.class_eval do
        def test_foo(*a); end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'test_foo'
    end
  
    it "creates an example to represent a test method" do
      @foo.class_eval do
        def test_bar; end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'test_bar'
    end
  
    it "creates examples for inherited methods" do
      @foo.class_eval do
        def test_bar; end
      end

      bar = Class.new(@foo)
      bar.examples.size.should == 1
      bar.examples.first.metadata[:description].should == 'test_bar'
    end
  
    it "creates examples for methods newly added to superclasses" do
      bar = Class.new(@foo)
      @foo.class_eval do
        def test_bar; end
      end
      bar.examples.size.should == 1
      bar.examples.first.metadata[:description].should == 'test_bar'
    end
  
    it "creates examples for methods added by inclusion of a module" do
      bar = Module.new do
        def test_bar; end
      end
      @foo.send(:include, bar)
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'test_bar'
    end
  end
  
  describe "running test methods" do
    it "runs the test methods as examples" do
      @foo.class_eval do
        def test_bar; end
      end
      
      eg_inst = mock_example_group_instance(@foo)
      eg_inst.should_receive(:test_bar).once
      
      @foo.run_all
    end
    
    it "brackets test methods with setup/teardown" do
      @foo.class_eval do
        def test_bar; end
        def test_baz; end
      end
    
      eg_inst = mock_example_group_instance(@foo)
      eg_inst.should_receive(:setup)   .once.ordered
      eg_inst.should_receive(:test_bar).once.ordered
      eg_inst.should_receive(:teardown).once.ordered
      eg_inst.should_receive(:setup)   .once.ordered
      eg_inst.should_receive(:test_baz).once.ordered
      eg_inst.should_receive(:teardown).once.ordered
    
      @foo.run_all
    end
    
    it "only calls setup/teardown once per test in subclasses" do
      @foo.class_eval do
        def test_baz; end
      end
      bar = Class.new(@foo)
      bar.class_eval do
        def test_quux; end
      end
    
      eg_inst = mock_example_group_instance(bar)
      eg_inst.should_receive(:setup)    .once.ordered
      eg_inst.should_receive(:test_baz) .once.ordered
      eg_inst.should_receive(:teardown) .once.ordered
      eg_inst.should_receive(:setup)    .once.ordered
      eg_inst.should_receive(:test_quux).once.ordered
      eg_inst.should_receive(:teardown) .once.ordered
    
      bar.run_all
    end
        
    it "records failed tests in RSpec style" do
      @foo.class_eval do
        def test_bar; flunk; end
      end
      @foo.run_all(@formatter)
      @formatter.failed_examples.size.should == 1
    end
    
    it "indicates failed tests in test/unit style" do
      @foo.class_eval do
        class <<self; attr_accessor :_passed; end
        def test_bar; flunk; end
        def teardown; self.class._passed = passed?; end
      end
      @foo.run_all
      @foo._passed.should == false
    end
  
    it "records passed tests in RSpec style" do
      @foo.class_eval do
        def test_bar; assert true; end
      end
      @foo.run_all(@formatter)
      @formatter.failed_examples.should be_empty
    end
    
    it "indicates passed tests in test/unit style" do
      @foo.class_eval do
        class <<self; attr_accessor :_passed; end
        def test_bar; assert true; end
        def teardown; self.class._passed = passed?; end
      end
      @foo.run_all
      @foo._passed.should == true
    end
  end
  
  describe "inherited" do
    it "adds the new subclass to RSpec.world.example_groups" do
      class SampleTestCase < RSpec::Unit::TestCase
      end
      RSpec.world.example_groups.should == [@foo, SampleTestCase]
    end
  end
  
  describe "ancestors" do
    before do
      @bar = Class.new(@foo)
    end
    
    it "removes TestCase from the end" do
      @bar.ancestors.should == [@bar, @foo]
    end
  end
  
  describe "find_caller_lines" do
    it "returns [] if the method name is not found" do
      @foo.send(:find_caller_lines, 'wrong').should be_empty
      bar = Class.new(@foo)
      bar.send(:find_caller_lines, 'wrong').should be_empty
    end
    
    it "returns a stack trace array if the name is found in caller_lines" do
      @foo.class_eval do
        def test_bar; end
      end
      
      @foo.send(:find_caller_lines, 'test_bar').should_not be_empty
    end

    it "returns a stack trace array if the name is found in the parent's caller_lines" do
      @foo.class_eval do
        def test_bar; end
      end
      bar = Class.new(@foo)
      
      bar.send(:find_caller_lines, 'test_bar').should_not be_empty
    end
  end
  
  describe "test class metadata" do
    before do
      class SampleTestCaseForName < RSpec::Unit::TestCase
      end
    end
  
    it "sets :description to the class name if the class has a name" do
      SampleTestCaseForName.metadata[:example_group][:description].should == "SampleTestCaseForName"
    end
    
    it "sets :description to '<Anonymous TestCase>' for anonymous test classes" do
      @foo.metadata[:example_group][:description].should == "<Anonymous TestCase>"
    end
    
    it "adds :test_unit => true" do
      @foo.metadata[:example_group][:test_unit].should be_true
    end
    
    it "sets :file_path to the file in which the class is first defined" do
      @foo.metadata[:example_group][:file_path].should == __FILE__
    end
    
    it "sets :line_number to the line where the class definition begins" do
      @foo.metadata[:example_group][:line_number].should == @foo_definition_line
    end
    
    it "sets :location to file_path and line_number" do
      @foo.metadata[:example_group][:location].should == "#{__FILE__}:#{@foo_definition_line}"
    end
        
    it "has nil for :block and :describes" do
      @foo.metadata[:example_group][:block].should be_nil
      @foo.metadata[:example_group][:describes].should be_nil
    end
    
    it "records test_case_info metadata" do
      @foo.class_eval do
        test_case_info :foo => :bar
      end
      @foo.metadata[:example_group][:foo].should == :bar
    end    
  end
  
  describe "test method metadata" do
    def find_example(example_group, name)
      example_group.examples.find{|e|e.description == name}
    end
    
    def test_baz_metadata
      find_example(@foo, 'test_baz').metadata
    end
        
    it "uses a test method's name as its :description" do
      @foo.class_eval do
        def test_baz; end
      end
      @foo.examples.first.metadata[:description].should == 'test_baz'
    end
  
    it "sets the test method's :full_description to ClassName#method_name" do
      @foo.class_eval do
        def test_baz; end
      end
      test_baz_metadata[:full_description].should == "#{@foo.metadata[:example_group][:description]}#test_baz"
    end
    
    it "adds :test_unit => true" do
      @foo.class_eval do
        def test_baz; end
      end
      test_baz_metadata[:test_unit].should be_true
    end    
  
    it "sets :file_path to the file where the method is defined" do
      @foo.class_eval do
        def test_baz; end
      end
      test_baz_metadata[:file_path].should == __FILE__
    end
    
    it "sets :line_number to the line where the method definition begins" do
      @foo.class_eval do
        def test_baz
        end
      end
      test_baz_metadata[:line_number].should == (__LINE__ - 3)
    end
    
    it "sets :location to file path and line number" do
      @foo.class_eval do
        def test_baz; end
      end
      test_baz_metadata[:location].should == "#{__FILE__}:#{__LINE__-2}"
    end
    
    it "sets :example_group and :behaviour to the test case class's metadata" do
      @foo.class_eval do
        def test_baz; end
      end
      test_baz_metadata[:example_group].should == @foo.metadata[:example_group]
    end
    
    it "records test_info metadata for next test method" do
      @foo.class_eval do
        test_info :foo => :bar
        def test_baz; end
      end
      test_baz_metadata[:foo].should == :bar
    end
    
    it "records test_info metadata *only* for next test method" do
      @foo.class_eval do
        test_info :foo => :bar
        def test_baz; end
        def test_quux; end
      end
      find_example(@foo, 'test_quux').metadata[:foo].should be_nil
    end
    
    context "inherited methods" do
      def test_baz_metadata
        find_example(@bar, 'test_baz').metadata
      end

      it "sets :file_path to the file where the method is defined" do
        @foo.class_eval do
          def test_baz; end
        end
        @bar = Class.new(@foo)
        
        test_baz_metadata[:file_path].should == __FILE__
      end

      it "sets :line_number to the line where the method definition begins" do
        @foo.class_eval do
          def test_baz; end
        end
        @bar = Class.new(@foo)

        test_baz_metadata[:line_number].should == (__LINE__ - 4)
      end

      it "sets :location to file path and line number" do
        @foo.class_eval do
          def test_baz; end
        end
        @bar = Class.new(@foo)
        
        test_baz_metadata[:location].should == "#{__FILE__}:#{__LINE__-4}"
      end
    end    
  end
  
  describe "examples within a test case" do
    it "allows 'example' to create an example" do
      @foo.class_eval do
        example "should bar" do end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'should bar'
    end
    
    it "supports 'test' as an alias of example" do
      @foo.class_eval do
        test "should bar" do end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'should bar'
      @foo.examples.first.metadata[:test_unit].should be_true
    end
    
    it "heeds 'alias_example_to'" do
      @foo.class_eval do
        alias_example_to :make_test
        make_test "should bar" do end
      end
      @foo.examples.size.should == 1
      @foo.examples.first.metadata[:description].should == 'should bar'
    end
    
    it "allows defining 'before' blocks" do
      @foo.class_eval do
        before {bar}
        def test_bar; end
      end
    
      eg_inst = mock_example_group_instance(@foo)
      eg_inst.should_receive(:bar).once
      
      @foo.run_all
    end
    
    it "allows defining 'after' blocks" do
      @foo.class_eval do
        after {bar}
        def test_bar; end
      end

      eg_inst = mock_example_group_instance(@foo)
      eg_inst.should_receive(:bar).once
      @foo.run_all
    end
    
    it "allows examples to use instance variables created in 'setup'" do
      @foo.class_eval do
        def setup; super; @quux = 42; end
        it "quux" do @quux.should == 42 end
      end
      @foo.run_all(@formatter)
      @formatter.failed_examples.should be_empty
    end
    
    it "allows test methods to use instance variables created in 'before' blocks" do
      @foo.class_eval do
        before { @quux = 42 }
        def test_quux; assert_equal 42, @quux; end
      end
      @foo.run_all(@formatter)
      @formatter.failed_examples.should be_empty
    end
  end

end
