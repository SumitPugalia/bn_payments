require "combine_pdf"

puts call(ARGV)

BEGIN {

  def call(args)
    function_name = args[0]
    send(function_name, args)
  end

  # merged pdf will be saved to output path
  # Need 3 params
    #path_to_file1, path_to_file2, output_path
  def merge_pdf(args)
    path_to_file1, path_to_file2, output_path = args[1], args[2], args[3]
    (get_pdf(path_to_file1) << get_pdf(path_to_file2)).save(output_path)
    return
  end

  def get_last_page_dimensions(args) 
    path = args[1]
    pdf = get_pdf(path)
    last_page = last_page(pdf)
    return page_dimensions(last_page)
  end

  def get_pdf(path, allow_optional_content=true)
    return CombinePDF.load(path, allow_optional_content: allow_optional_content) 
  end

  # fetches last page of pdf
  def last_page(pdf) 
    return pdf.pages.last
  end

  # expects pdf page
  # return in mm
  def page_dimensions(page) 
    bbox   = page[:MediaBox]
    width  = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    # reverse dimensions if pdf is roatated
    width, height = height, width if [90,270].include?(page[:Rotate])
    return pt2mm(width), pt2mm(height), page[:Rotate].to_i
  end

  def pt2mm(pt)
    (pt2in(pt) * 25.4).round(2)
  end

  def pt2in(pt)
    (pt / 72.0).round(2)
  end
  
}
