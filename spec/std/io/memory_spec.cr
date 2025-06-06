require "../spec_helper"

describe IO::Memory do
  it "writes" do
    io = IO::Memory.new
    io.bytesize.should eq(0)
    io.write Slice.new("hello".to_unsafe, 3)
    io.bytesize.should eq(3)
    io.rewind
    io.gets_to_end.should eq("hel")
  end

  it "writes big" do
    s = "hi" * 100
    io = IO::Memory.new
    io.write Slice.new(s.to_unsafe, s.bytesize)
    io.rewind
    io.gets_to_end.should eq(s)
  end

  it "write raises EOFError" do
    io = IO::Memory.new
    initial_capacity = io.@capacity
    expect_raises(IO::EOFError) do
      io.write Slice.new(Pointer(UInt8).null, Int32::MAX)
    end
    # nothing get's written
    io.bytesize.should eq 0
    io.@capacity.should eq initial_capacity
  end

  it "reads byte" do
    io = IO::Memory.new("abc")
    io.read_byte.should eq('a'.ord)
    io.read_byte.should eq('b'.ord)
    io.read_byte.should eq('c'.ord)
    io.read_byte.should be_nil
  end

  it "raises if reading when closed" do
    io = IO::Memory.new("abc")
    io.close
    expect_raises(IO::Error, "Closed stream") do
      io.read(Slice.new(3, 0_u8))
    end
  end

  it "raises if clearing when closed" do
    io = IO::Memory.new("abc")
    io.close
    expect_raises(IO::Error, "Closed stream") do
      io.clear
    end
  end

  describe "#to_s" do
    it "appends to another buffer" do
      s1 = IO::Memory.new
      s1 << "hello"

      s2 = IO::Memory.new
      s1.to_s(s2)
      s2.to_s.should eq("hello")
    end

    it "appends to itself" do
      io = IO::Memory.new
      io << "." * 33
      old_capacity = io.@capacity
      io.to_s(io)
      io.to_s.should eq "." * 66
      # Ensure that the buffer is resized, otherwise the spec doesn't work
      io.@capacity.should_not eq old_capacity
    end

    {% if flag?(:without_iconv) %}
      pending "encoding"
    {% else %}
      describe "encoding" do
        it "returns String" do
          io = IO::Memory.new
          io.set_encoding "UTF-16LE"
          io << "abc"
          io.to_s.should eq "abc"
          io.to_slice.should eq Bytes[0x61, 0, 0x62, 0, 0x63, 0]
        end

        it "writes to IO" do
          io1 = IO::Memory.new
          io1.set_encoding "UTF-32LE"

          io2 = IO::Memory.new
          io2.set_encoding "UTF-16LE"

          io1.write_string "abc😂".to_slice
          io1.to_s io2
          byte_slice = io2.to_slice
          utf16_slice = byte_slice.unsafe_slice_of(UInt16)

          String.from_utf16(utf16_slice).should eq "abc😂"
          byte_slice.should eq Bytes[0x61, 0, 0x62, 0, 0x63, 0, 0x3D, 0xD8, 0x02, 0xDE]
          utf16_slice.should eq Slice[0x0061, 0x0062, 0x0063, 0xD83D, 0xDE02]
        end
      end
    {% end %}
  end

  it "reads single line content" do
    io = IO::Memory.new("foo")
    io.gets.should eq("foo")
  end

  it "reads each line" do
    io = IO::Memory.new("foo\r\nbar\n")
    io.gets.should eq("foo")
    io.gets.should eq("bar")
    io.gets.should be_nil
  end

  it "reads each line with chomp = false" do
    io = IO::Memory.new("foo\r\nbar\r\n")
    io.gets(chomp: false).should eq("foo\r\n")
    io.gets(chomp: false).should eq("bar\r\n")
    io.gets(chomp: false).should be_nil
  end

  it "gets with char as delimiter" do
    io = IO::Memory.new("hello world")
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should be_nil
  end

  it "does gets with char and limit" do
    io = IO::Memory.new("hello\nworld\n")
    io.gets('o', 2).should eq("he")
    io.gets('w', 10_000).should eq("llo\nw")
    io.gets('z', 10_000).should eq("orld\n")
    io.gets('a', 3).should be_nil
  end

  it "does gets with limit" do
    io = IO::Memory.new("hello\nworld")
    io.gets(3).should eq("hel")
    io.gets(3).should eq("lo\n")
    io.gets(3).should eq("wor")
    io.gets(3).should eq("ld")
    io.gets(3).should be_nil
  end

  it "does gets with char and limit without off-by-one" do
    io = IO::Memory.new("test\nabc")
    io.gets('a', 5).should eq("test\n")
    io = IO::Memory.new("test\nabc")
    io.gets('a', 6).should eq("test\na")
  end

  it "raises if invoking gets with negative limit" do
    io = IO::Memory.new("hello\nworld\n")
    expect_raises ArgumentError, "Negative limit" do
      io.gets(-1)
    end
  end

  it "write single byte" do
    io = IO::Memory.new
    io.write_byte 97_u8
    io.to_s.should eq("a")
  end

  it "writes and reads" do
    io = IO::Memory.new
    io << "foo" << "bar"
    io.rewind
    io.gets.should eq("foobar")
  end

  it "can be converted to slice" do
    str = IO::Memory.new
    str.write_byte 0_u8
    str.write_byte 1_u8
    slice = str.to_slice
    slice.size.should eq(2)
    slice[0].should eq(0_u8)
    slice[1].should eq(1_u8)
  end

  it "reads more than available (#1229)" do
    s = "h" * (10 * 1024)
    str = IO::Memory.new(s)
    str.gets(11 * 1024).should eq(s)
  end

  it "writes after reading" do
    io = IO::Memory.new
    io << "abcdefghi"
    io.rewind
    io.gets(3)
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abcxyzghi")
  end

  it "has a size" do
    IO::Memory.new("foo").size.should eq(3)
  end

  it "can tell" do
    io = IO::Memory.new("foo")
    io.tell.should eq(0)
    io.gets(2)
    io.tell.should eq(2)
  end

  it "can seek set" do
    io = IO::Memory.new("abcdef")
    io.seek(3)
    io.tell.should eq(3)
    io.gets(1).should eq("d")
  end

  it "raises if seek set is negative" do
    io = IO::Memory.new("abcdef")
    expect_raises(ArgumentError, "Negative pos") do
      io.seek(-1)
    end
  end

  it "can seek past the end" do
    io = IO::Memory.new
    io << "abc"
    io.rewind
    io.seek(6)
    io.gets_to_end.should eq("")
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abc\u{0}\u{0}\u{0}xyz")
  end

  it "can seek current" do
    io = IO::Memory.new("abcdef")
    io.seek(2)
    io.seek(1, IO::Seek::Current)
    io.gets(1).should eq("d")
  end

  it "raises if seek current leads to negative value" do
    io = IO::Memory.new("abcdef")
    io.seek(2)
    expect_raises(ArgumentError, "Negative pos") do
      io.seek(-3, IO::Seek::Current)
    end
  end

  it "can seek from the end" do
    io = IO::Memory.new("abcdef")
    io.seek(-2, IO::Seek::End)
    io.gets(1).should eq("e")
  end

  it "can be closed" do
    io = IO::Memory.new
    io << "abc"
    io.close
    io.closed?.should be_true

    expect_raises(IO::Error, "Closed stream") { io.gets_to_end }
    expect_raises(IO::Error, "Closed stream") { io.print "hi" }
    expect_raises(IO::Error, "Closed stream") { io.seek(1) }
    expect_raises(IO::Error, "Closed stream") { io.gets }
    expect_raises(IO::Error, "Closed stream") { io.read_byte }
  end

  it "seeks with pos and pos=" do
    io = IO::Memory.new("abcdef")
    io.pos = 4
    io.gets(1).should eq("e")
    io.pos -= 2
    io.gets(1).should eq("d")
  end

  it "clears" do
    io = IO::Memory.new
    io << "abc"
    io.rewind
    io.gets(1)
    io.clear
    io.pos.should eq(0)
    io.gets_to_end.should eq("")
  end

  it "raises if negative capacity" do
    expect_raises(ArgumentError, "Negative capacity") do
      IO::Memory.new(-1)
    end
  end

  it "raises if capacity too big" do
    expect_raises(ArgumentError, "Capacity too big") do
      IO::Memory.new(UInt32::MAX)
    end
  end

  it "creates from string" do
    io = IO::Memory.new "abcdef"
    io.gets(2).should eq("ab")
    io.gets(3).should eq("cde")

    expect_raises(IO::Error, "Read-only stream") do
      io.print 1
    end
  end

  it "creates from slice" do
    slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
    io = IO::Memory.new slice
    io.gets(2).should eq("ab")
    io.gets(3).should eq("cde")
    io.print 'x'

    String.new(slice).should eq("abcdex")

    expect_raises(IO::Error, "Non-resizeable stream") do
      io.print 'z'
    end
  end

  it "creates from slice, non-writeable" do
    slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
    io = IO::Memory.new slice, writeable: false

    expect_raises(IO::Error, "Read-only stream") do
      io.print 'z'
    end
  end

  it "creates from read-only slice" do
    slice = Slice.new(6, read_only: true) { |i| ('a'.ord + i).to_u8 }
    io = IO::Memory.new slice

    expect_raises(IO::Error, "Read-only stream") do
      io.print 'z'
    end
  end

  it "writes past end" do
    io = IO::Memory.new
    io.pos = 1000
    io.print 'a'
    io.to_slice.should eq(Bytes.new(1001).tap { |bytes| bytes[-1] = 97 })
  end

  it "writes past end with write_byte" do
    io = IO::Memory.new
    io.pos = 1000
    io.write_byte 'a'.ord.to_u8
    io.to_slice.should eq(Bytes.new(1001).tap { |bytes| bytes[-1] = 97 })
  end

  it "reads at offset" do
    io = IO::Memory.new("hello world")

    io.read_at(6, 3) do |sub|
      sub.gets_to_end.should eq("wor")

      expect_raises(IO::Error, "Read-only stream") do
        io << "hello"
      end
    end

    io.read_at(0, 11) do |sub|
      sub.gets_to_end.should eq("hello world")
    end

    io.read_at(11, 0) do |sub|
      sub.gets_to_end.should eq("")
    end
  end

  it "raises when reading at offset outside of bounds" do
    io = IO::Memory.new("hello world")

    expect_raises(ArgumentError, "Negative bytesize") do
      io.read_at(3, -1) { }
    end

    expect_raises(ArgumentError, "Offset out of bounds") do
      io.read_at(12, 1) { }
    end

    expect_raises(ArgumentError, "Bytesize out of bounds") do
      io.read_at(6, 6) { }
    end
  end

  it "consumes with gets_to_end" do
    io = IO::Memory.new("hello world")
    io.gets_to_end.should eq("hello world")
    io.gets_to_end.should eq("")
  end

  it "consumes with getb_to_end" do
    io = IO::Memory.new(Bytes[0, 1, 3, 6, 10, 15])
    io.getb_to_end.should eq(Bytes[0, 1, 3, 6, 10, 15])
    io.getb_to_end.should eq(Bytes[])
    io.seek(3)
    bytes = io.getb_to_end
    bytes.should eq(Bytes[6, 10, 15])
    bytes.read_only?.should be_false

    io.seek(3)
    io.write(Bytes[2, 4, 5])
    bytes.should eq(Bytes[6, 10, 15])

    io.seek(10)
    io.getb_to_end.should eq(Bytes[])
  end

  it "peeks" do
    str = "hello world"
    io = IO::Memory.new(str)

    io.peek.should eq("hello world".to_slice)
    io.pos.should eq(0)

    io.skip(3)
    io.peek.should eq("lo world".to_slice)

    io.skip_to_end
    io.peek.should eq(Bytes.empty)
  end

  it "peek readonly" do
    str = "hello world"
    io = IO::Memory.new(str)

    slice = io.peek
    expect_raises(Exception) do
      slice[0] = 0
    end
  end

  it "skips" do
    io = IO::Memory.new("hello")
    io.skip(2)
    io.gets_to_end.should eq("llo")

    io.rewind
    io.skip(5)
    io.gets_to_end.should eq("")

    io.rewind

    expect_raises(IO::EOFError) do
      io.skip(6)
    end
  end

  it "skips_to_end" do
    io = IO::Memory.new("hello")
    io.skip_to_end
    io.gets_to_end.should eq("")
  end

  {% unless flag?(:without_iconv) %}
    describe "encoding" do
      describe "decode" do
        it "gets_to_end" do
          str = "Hello world" * 200
          io = IO::Memory.new(str.encode("UCS-2LE"))
          io.set_encoding("UCS-2LE")
          io.gets_to_end.should eq(str)
        end

        it "gets" do
          str = "Hello world\nFoo\nBar\n" + ("1234567890" * 1000)
          io = IO::Memory.new(str.encode("UCS-2LE"))
          io.set_encoding("UCS-2LE")
          io.gets(chomp: false).should eq("Hello world\n")
          io.gets(chomp: false).should eq("Foo\n")
          io.gets(chomp: false).should eq("Bar\n")
        end

        it "gets with chomp = false" do
          str = "Hello world\nFoo\nBar\n" + ("1234567890" * 1000)
          io = IO::Memory.new(str.encode("UCS-2LE"))
          io.set_encoding("UCS-2LE")
          io.gets.should eq("Hello world")
          io.gets.should eq("Foo")
          io.gets.should eq("Bar")
        end

        it "reads char" do
          str = "x\nHello world" + ("1234567890" * 1000)
          io = IO::Memory.new(str.encode("UCS-2LE"))
          io.set_encoding("UCS-2LE")
          io.gets(chomp: false).should eq("x\n")
          str = str[2..-1]
          str.each_char do |char|
            io.read_char.should eq(char)
          end
          io.read_char.should be_nil
        end
      end
    end
  {% end %}

  it "allocates for > 1 GB", tags: %w[slow] do
    io = IO::Memory.new
    mbstring = "a" * 1024 * 1024
    1024.times { io << mbstring }

    io.bytesize.should eq(1 << 30)
    io.@capacity.should eq 1 << 30

    io << mbstring

    io.bytesize.should eq (1 << 30) + (1 << 20)
    io.@capacity.should eq Int32::MAX

    1022.times { io << mbstring }

    io.write mbstring.to_slice[0..-4]
    io << "a"
    expect_raises(IO::EOFError) do
      io << "a"
    end
  end
end
