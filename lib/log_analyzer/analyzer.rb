#Todo - define custom exception classes
module LogAnalyzer
  class Analyzer
    attr_reader :levels
    def initialize(filepath)
      @filepath = filepath
      raise("can't locate the given file") if !File.exists?(filepath)
      @levels = %w{DEBUG INFO ERROR}
    end
    
    def get_lines(level, include_upper = false)
      raise("not a valid log level") if !@levels.include?(level)
      pattern = [level]
      pattern = @levels[@levels.index(level) .. -1] if include_upper #levels to be included
      pattern = pattern.join("|")
      lines = grep_pattern(pattern).split(/\n/)
      lines.map{|line| parse_line(line)} 
    end
    
    def grep_pattern(pattern)
      `cat #{@filepath} | grep -wE \"#{pattern}\"`
    end
    
    def get_counts
      counts = {}
      @levels.each do |l|
        counts[l.downcase.to_sym] = count(l)
      end
      counts
    end
    
    private
    def parse_line(line)
      line_no = line[/^\s*\d+\:/].strip
      date = line[/\[\d+\-\d+\-\d+\s+\d+\:\d+\]/]
      level = line[/ERROR|INFO|DEBUG/]
      msg = line[/(?<=ERROR|DEBUG|INFO).+$/].strip
      [line_no, date, level, msg]
    end
    
    def count(level)
      `cat #{@filepath} | grep -w  #{level} | wc -l`.strip
    end

  end
end  
