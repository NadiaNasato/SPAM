require 'pathname'

def prepare_environment
	base_dir = Pathname.new(__FILE__).parent
	gem_dir = base_dir + 'gems' + 'ruby' + '1.8' + 'gems'
	gems = gem_dir.children.select { |i| i.directory? }

	gems.each do |gem|
        	abs_path = (gem + 'lib').expand_path.to_s
	        $LOAD_PATH.unshift(abs_path)
	end
end

prepare_environment()
