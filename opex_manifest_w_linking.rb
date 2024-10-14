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
    puts ""
    puts "Use for linking to ArchivesSpace"
    puts "Folder structure must be of the form"
    puts "Top Level Wrapper"
    puts "  archival_object_xxxx"
    puts "    {Digital Object Identifier}"
    puts "      assets(s)"
    puts "  archival_object_yyyy"
    puts "    {Digital Object Identifier}"
    puts "      asset(s)"
    puts "Archival object ids and digital object identifiers *must* be unique across all archival and digital objects"
    puts ""
    puts "What is the absolute path to the directory to be ingested"
    dir = gets.chomp

    # handle windows paths
    # OPEX only wants linux like path separators
    linux_like_dir = dir.gsub(/\\/,'/')

    # build top level opex
    create_opex_manifest(Pathname.new(linux_like_dir))
    ao_link_dirs = Pathname(linux_like_dir).children.select(&:directory?)
 
    enumerate_dirs(ao_link_dirs, linux_like_dir)
    build_opex_xml

    # iterate through the archival object wrapper directories
    ao_link_dirs.each do |ao_link_dir|
      @@opex_files = []
      @@opex_folders = []
      create_opex_manifest(Pathname.new(ao_link_dir))
      asset_dirs = ao_link_dir.children.select(&:directory?)

      enumerate_dirs(asset_dirs, ao_link_dir.to_s)
      build_as_link_opex_xml(ao_link_dir.to_s.sub(linux_like_dir + '/',''))

      # iterate through the asset directories
      asset_dirs.each do |asset_dir|
        @@opex_files = []
        @@opex_folders = []
        create_opex_manifest(Pathname.new(asset_dir))
        files, dirs = Pathname.glob(File.join(asset_dir.to_s, '**', '*'), File::FNM_DOTMATCH).partition(&:file?)

        enumerate_dirs(dirs, asset_dir.to_s)
        enumerate_files(files, asset_dir.to_s)
        build_asset_opex_xml(asset_dir.to_s.sub(ao_link_dir.to_s + '/',''))
      end
    end

  end

  # create or update the manifest files
  # note the naming convention
  def create_opex_manifest(dir)
    @@opex_manifest = File.new(File.join(dir.realpath.to_s, dir.basename.to_s + '.opex'), 'w')
  end

  # build the OPEX contents - a manifest of folders
  def build_opex_xml
    @@opex_xml = Nokogiri::XML::Builder.new do |xml|
      xml['opex'].OPEXMetadata('xmlns:opex' => 'http://www.openpreservationexchange.org/opex/v1.2') do
        xml.Transfer {
          xml.Manifest {
            xml.Folders {
              @@opex_folders.each do |fld|
                xml.Folder fld
              end
            }
          }
        }
      end
    end
    @@opex_manifest.write(@@opex_xml.to_xml)
    @@opex_manifest.close
  end

  # build the archival object OPEX - a manifest of folders and additional Preservica properties
  def build_as_link_opex_xml(as_dir)
    @@opex_xml = Nokogiri::XML::Builder.new do |xml|
      xml['opex'].OPEXMetadata('xmlns:opex' => 'http://www.openpreservationexchange.org/opex/v1.2') do
        xml.Transfer {
          xml.Manifest {
            xml.Folders {
              @@opex_folders.each do |fld|
                xml.Folder fld
              end
            }
          }
        }
        xml.Properties {
          xml.Title(as_dir)
          xml.Securitydescriptor('open')
          xml.Identifiers {
            xml.Identifier(as_dir, :type => 'code')
          }
        }
        xml.DescriptiveMetadata {
          xml.LegacyXIP('xmlns' => 'http://preservica.com/LegacyXIP') do
            xml.Virtual('false')
          end
        }
      end
    end
    @@opex_manifest.write(@@opex_xml.to_xml)
    @@opex_manifest.close
  end

  # build the asset OPEX - fixity list, a manifest of folders and files, and other Preservica properties
  def build_asset_opex_xml(asset_dir)
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
            puts "#{@@opex_folders.length}"
            if @@opex_folders.length > 0
              xml.Folders {
                @@opex_folders.each do |fld|
                  xml.Folder fld
                end
              }
            end
          }
        }
        xml.Properties {
          xml.Title(asset_dir)
          xml.Securitydescriptor('open')
          xml.Identifiers {
            xml.Identifier(asset_dir, :type => 'code')
          }
        }
        xml.DescriptiveMetadata {
          xml.LegacyXIP('xmlns' => 'http://preservica.com/LegacyXIP') do
            xml.AccessionRef ('catalog')
          end
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
      next if dir.to_s.sub(base_dir + '/','') == '.' || dir.to_s.end_with?('.')
      next unless dir.to_s.match(@@files_to_skip).nil?
      @@opex_folders << dir.to_s.sub(base_dir + '/','')
    end
  end

end

CreateOpexManifest.new
