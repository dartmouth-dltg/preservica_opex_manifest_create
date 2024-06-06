#!/usr/bin/ruby
require 'rubygems'
require 'nokogiri'
require 'pathname'
require 'digest/sha1'

class CreateOpexManifest

  @@opex_manifest
  @@opex_xml
  @@opex_files = []
  @@opex_folders = []

  # match CyberDuck filters
  @@files_to_skip = /.*~\..*,\.DS_Store|\.DS_Store|\.svn|CVS|RCS|SCCS|\.git|\.bzr|\.bzrignore|\.bzrtags|\.hg|\.hgignore|\.hgtags|_darcs|\.file-segments|desktop\.ini|(T|t)humbs\.db/

  def initialize
    get_files
  end

  def get_files
    puts "What is the absolute path to the directory to be ingested"
    dir = gets.chomp

    # handle windows paths
    # OPEX only wants linux like path separators
    linux_like_dir = dir.gsub(/\\/,'/')

    create_opex_manifest(Pathname.new(linux_like_dir))

    files, dirs = Pathname.glob(File.join(linux_like_dir, '**', '*'), File::FNM_DOTMATCH).partition(&:file?)

    enumerate_dirs(dirs, linux_like_dir)
    enumerate_files(files, linux_like_dir)

    build_opex_xml
  end

  # create or update the manifest file
  # note the naming convention
  def create_opex_manifest(dir)
    @@opex_manifest = File.new(File.join(dir.realpath.to_s, dir.basename.to_s + '.opex'), 'w')
  end

  # build the OPEX contents - fixity list and a manifest of folders and files
  def build_opex_xml
    @@opex_xml = Nokogiri::XML::Builder.new do |xml|
      xml['opex'].OPEXMetadata('xmlns:opex' => 'http://www.openpreservationexchange.org/opex/v1.2') do
        xml.Transfer {
          xml.Fixities {
            @@opex_files.each do |file|
                xml.Fixity('path' => file['file_path'], 'type' => 'SHA-1', 'value' => file['file_digest'])
            end
          }
          xml.Manifest {
            if @@opex_files.length > 0
              xml.Files {
                @@opex_files.each do |fl|
                  xml.File(fl['file_path'], :type => 'content')
                end
              }
            end
            if @@opex_folders.length > 0
              xml.Folders {
                @@opex_folders.each do |fld|
                  xml.Folder fld
                end
              }
            end
          }
        }
      end
    end
    @@opex_manifest.write(@@opex_xml.to_xml)
    @@opex_manifest.close
  end

  # create an array of all file checksums and paths
  def enumerate_files(files, base_dir)
    files.each do |file|
      # skip the manifest file
      next if file.to_s == @@opex_manifest.path
      next if file.to_s.sub(base_dir + '/','') == '.'
      next unless file.to_s.match(@@files_to_skip).nil?
      checksum = Digest::SHA1.file file
      # relative file paths to base directory
      @@opex_files << {'file_path' => file.to_s.sub(base_dir + '/',''), 'file_digest' => checksum}
    end
  end

  # create an array of all subdirectories
  def enumerate_dirs(dirs, base_dir)
    dirs.each do |dir|
      next if dir.to_s.sub(base_dir + '/','') == '.'
      next unless dir.to_s.match(@@files_to_skip).nil?
      @@opex_folders << dir.to_s.sub(base_dir + '/','')
    end
  end

end

CreateOpexManifest.new