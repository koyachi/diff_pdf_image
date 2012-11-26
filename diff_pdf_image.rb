#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'fileutils'
require 'pathname'
require 'tmpdir'

$tmpdir = nil
def tmpdir
  $tmpdir ||= Dir.mktmpdir("pdf_diff_" + Time.now.to_i.to_s)
end

class PDF
  attr_accessor :src_path

  def initialize(src_path)
    @src_path = Pathname(src_path)
  end

  def to_images(output_dir=tmpdir)
    dst_path = Pathname(output_dir)
    command =<<COMMAND
gs \
-dSAFER \
-dBATCH \
-dNOPAUSE \
-sDEVICE=jpeg \
-r150 \
-dTextAlphaBits=4 \
-dGraphicsAlphaBits=4 \
-dMaxStripSize=8192 \
-sOutputFile=#{dst_path.expand_path + @src_path.basename}_%d.jpg \
#{@src_path.expand_path}
COMMAND
    system(command)
    re = /^.*\.pdf_(\d+)\.jpg$/
    result_images = Dir.glob("#{dst_path.expand_path}/*#{@src_path.basename.to_s}*.jpg").sort do |a,b|
      a_no = a.match(re)[1].to_i
      b_no = b.match(re)[1].to_i
      a_no <=> b_no
    end
    result_images.map {|ri| Image.new(ri)}
  end

  def to_image(output_dir, page_no)
    # TODO
  end
end

class Image
  attr_accessor :path

  def initialize(path)
    @path = Pathname(path)
  end

  def to_grayscale_image(dst_path)
    dst_path = Pathname(dst_path)
    command =<<COMMAND
convert \
#{@path.expand_path} \
-type GrayScale \
#{dst_path.expand_path}
COMMAND
    system(command)
    Image.new(dst_path.expand_path)
  end

  def to_red_image
    result_path = Pathname(tmpdir) + (@path.basename.to_s + ".red" + @path.extname.to_s)
    command =<<COMMAND
convert \
#{@path} \
+level-colors Red,White \
#{result_path}
COMMAND
    system(command)
    Image.new(result_path.expand_path)
  end

  def to_blue_image
    result_path = Pathname(tmpdir) + (@path.basename.to_s + ".blue" + @path.extname.to_s)
    command =<<COMMAND
convert \
#{@path} \
+level-colors Blue,White \
#{result_path}
COMMAND
    system(command)
    Image.new(result_path.expand_path)
  end

  def diff(other)
    self.diff(self.path, other.path)
  end

  class << self
    def diff(image_a_path, image_b_path, suffix, output_dir=tmpdir)
      dst_dir_path = Pathname(output_dir)
      image_a = Image.new(image_a_path).to_grayscale_image((dst_dir_path + "image_a_#{suffix}_gray.png").expand_path)
      image_b = Image.new(image_b_path).to_grayscale_image((dst_dir_path + "image_b_#{suffix}_gray.png").expand_path)
      puts "dst_dir_path = #{dst_dir_path}"
      puts "image_a = #{image_a.path}"
      puts "image_b = #{image_b.path}"
      path_a = Pathname(image_a.to_red_image.path)
      path_b = Pathname(image_b.to_blue_image.path)
      result_path = dst_dir_path + ("diff_" + path_a.basename.to_s + "_" + path_b.basename.to_s + suffix + ".png")
      command=<<COMMAND
convert \
#{path_a} #{path_b} \
-compose Multiply \
-composite \
#{result_path}
COMMAND
      system(command)
      result_path
    end
  end
end

module Differ
  class << self
    def diff_page(pdf1_path, pdf2_path, page_no=nil)
      pdf1 = PDF.new(pdf1_path)
      pdf2 = PDF.new(pdf2_path)
      if page_no != nil
        # TODO
        #cover_image1 = pdf1.to_image(:page_no => page_no).to_red_image
        #cover_image2 = pdf2.to_image(:page_no => page_no).to_blue_image
        #diff_image = Image.diff_image(cover_image1, cover_image2)
      else
        cover_images1 = pdf1.to_images(tmpdir)
        cover_images2 = pdf2.to_images(tmpdir)
        results = []
        cover_images1.each_with_index do |image1, i|
          image2 = cover_images2[i]
          results.push(Image.diff(image1.path, image2.path, "%03d" % i.to_s))
        end
        results
      end
    end
  end
end


pdf1_path = ARGV[0]
pdf2_path = ARGV[1]
#page_no = nil

diff_image_path = Differ.diff_page(pdf1_path, pdf2_path)

def cp_diff_images(images, dstdir="./diff_images_#{Time.now.to_i.to_s}")
  Dir.mkdir(dstdir)
  images.each do |path|
    FileUtils.cp(path, Pathname.new(dstdir) + Pathname.new(path).basename)
  end
  system("open #{dstdir}")
end
cp_diff_images(diff_image_path)
FileUtils.rm_rf(tmpdir)
