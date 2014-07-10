module ::Af::OptionParser
  class Columnizer
    # Convert an array into a single string, where each item consumes a static
    # number of characters.  Long fields are truncated and small ones are padded.
    #
    # *Arguments*
    #   * fields - array of objects that respond to "to_s"
    #   * sized - character count for each field in the new string????
    def columnized_row(fields, sized)
      r = []
      fields.each_with_index do |f, i|
        r << sprintf("%0-#{sized[i]}s", f.to_s.gsub(/\\n\\r/, '').slice(0, sized[i]))
      end
      return r.join('   ')
    end

    # Converts an array of arrays into a single array of columnized strings.
    #
    # *Arguments*
    #   * rows - arrays to convert
    #   * options - hash of options, includes:
    #     :max_width => <integer max width of columns>
    def columnized(rows, options = {})
      sized = {}
      rows.each do |row|
        row.each_index do |i|
          value = row[i]
          sized[i] = [sized[i].to_i, value.to_s.length].max
          sized[i] = [options[:max_width], sized[i].to_i].min if options[:max_width]
        end
      end

      return rows.map { |row| "    " + columnized_row(row, sized).rstrip }
    end
  end
end
