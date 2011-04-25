
$: << 'x86_64-linux'

require 'gtk2'
require 'bgpixbuf'

ARGV.each do |fn|

loader = BgPixbuf::Loader.new(fn)

loop do
	(STDOUT << ".").flush
	sleep 0.05
	break if loader.pixbuf
end

pb = loader.pixbuf

loader = nil

GC.start

loader = 1


GC.start

puts "#{pb.width}x#{pb.height}"
end

