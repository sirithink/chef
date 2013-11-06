#
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Author:: Jesse Campbell (<hikeit@gmail.com>)
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2013 Jesse Campbell
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'stringio'
require 'chef/file_cache'
require 'chef/json_compat'
require 'chef/digester'
require 'chef/exceptions'

class Chef
  class Provider
    class RemoteFile

      # == CacheControlData
      # Implements per-uri storage of cache control data for a remote resource
      # along with a sanity check checksum of the file in question.
      # Provider::RemoteFile protocol implementation classes can use this
      # information to avoid re-fetching files when the current copy is up to
      # date. The way this information is used is protocol-dependent. For HTTP,
      # this information is sent to the origin server via headers to make a
      # conditional GET request.
      #
      # == API
      # The general shape of the API is active-record-the-pattern-like. New
      # instances should be instantiated via
      # `CacheControlData.load_and_validate`, which will do a find-or-create
      # operation and then sanity check the data against the checksum of the
      # current copy of the file. If there is no data or the sanity check
      # fails, the `etag` and `mtime` attributes will be set to nil; otherwise
      # they are populated with the previously saved values.
      #
      # After fetching a file, the CacheControlData instance should be updated
      # with new etag, mtime and checksum values in whatever format is
      # preferred by the protocol used. Then call #save to save the data to disk.
      class CacheControlData

        def self.load_and_validate(uri, validation_fields)
          ccdata = new(uri)
          ccdata.load
          ccdata.validate!(validation_fields)
          ccdata
        end

        # Entity Tag of the resource. HTTP-specific. See also:
        # http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.3.2
        # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.19
        attr_accessor :etag

        # Last modified time of the remote resource. Different protocols will
        # use different types for this field (e.g., string representation of a
        # specific date format, integer, etc.) For HTTP-specific references,
        # see:
        # * http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3
        # * http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.3.1
        # * http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.25
        attr_accessor :mtime

        # SHA2-256 Hash of the deployed file to validate it has not changed
        attr_accessor :validation_checksum
        # mtime of the deployed file to validate it has not changed
        attr_accessor :validation_mtime
        # size of the deployed file to validate it has not changed
        attr_accessor :validation_size

        # URI of the resource as a String. This is the "primary key" used for
        # storage and retrieval.
        attr_reader :uri

        def initialize(uri)
          uri = uri.dup
          uri.password = "XXXX" unless uri.userinfo.nil?
          @uri = uri.to_s
        end

        def load
          if previous_cc_data = load_data
            apply(previous_cc_data)
            self
          else
            false
          end
        end

        def validate!(validation_fields)
          failed = false

          # FIXME: dry this up
          if validation_fields.has_key(:checksum)
            if validation_fields[:checksum].nil? or validation_checksum != validation_fields[:checksum]
              failed = true
            end
          end
          if validation_fields.has_key(:mtime)
            if validation_fields[:mtime].nil? or validation_mtime != validation_fields[:mtime]
              failed = true
            end
          end
          if validation_fields.has_key(:size)
            if validation_fields[:size].nil? or validation_size != validation_fields[:size]
              failed = true
            end
          end

          if failed
            reset!
            false
          else
            true
          end
        end

        # Saves the data to disk using Chef::FileCache. The filename is a
        # sanitized version of the URI with a MD5 of the same URI appended (to
        # avoid collisions between different URIs having the same sanitized
        # form).
        def save
          Chef::FileCache.store("remote_file/#{sanitized_cache_file_basename}", json_data)
        end

        # :nodoc:
        # JSON representation of this object for storage.
        def json_data
          Chef::JSONCompat.to_json(hash_data)
        end

        private

        def hash_data
          as_hash = {}
          as_hash["etag"]                = etag
          as_hash["mtime"]               = mtime
          as_hash["validation_checksum"] = validation_checksum
          as_hash["validation_mtime"]    = validation_mtime
          as_hash["validation_size"]     = validation_size
          as_hash
        end

        def reset!
          @etag, @mtime = nil, nil
        end

        def apply(previous_cc_data)
          @etag = previous_cc_data["etag"]
          @mtime = previous_cc_data["mtime"]
          if previous_cc_data.has_key?("validation_checksum")
            @validation_checksum = previous_cc_data["validation_checksum"]
          else
            @validation_checksum = previous_cc_data["checksum"]
          end
          @validation_mtime    = previous_cc_data["validation_mtime"]
          @validation_size     = previous_cc_data["validation_size"]
        end

        def load_data
          Chef::JSONCompat.from_json(load_json_data)
        rescue Chef::Exceptions::FileNotFound, Yajl::ParseError
          false
        end

        def load_json_data
          Chef::FileCache.load("remote_file/#{sanitized_cache_file_basename}")
        end

        def sanitized_cache_file_basename
          # Scrub and truncate in accordance with the goals of keeping the name
          # human-readable but within the bounds of local file system
          # path length limits
          scrubbed_uri = uri.gsub(/\W/, '_')[0..63]
          uri_md5 = Chef::Digester.instance.generate_md5_checksum(StringIO.new(uri))
          "#{scrubbed_uri}-#{uri_md5}.json"
        end

      end
    end
  end
end
