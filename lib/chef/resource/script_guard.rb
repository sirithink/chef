#
# Author:: Adam Edwards (<adamed@opscode.com>)
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

class Chef
  class Resource
    class ScriptGuard

      def initialize(parent_resource, node, guard_resource_class_id)
        @last_command_succeeded = false
        @parent_resource_name = parent_resource.name
        @guard_resource_class = resource_class_from_id(node, guard_resource_class_id)
        @architecture = parent_resource.respond_to?(:architecture) ? parent_resource.architecture : nil

        events = Chef::EventDispatch::Dispatcher.new
        @run_context = Chef::RunContext.new(node, {}, events)
      end

      def run_command(command, command_opts)
        guard_resource = @guard_resource_class.new("chefscriptguard-" + @guard_resource_class.to_s + "-" + @parent_resource_name, @run_context)

        guard_resource.code command
        guard_resource.architecture @architecture if @architecture
        guard_resource.returns 0

        guard_resource.user(command_opts[:user]) if command_opts.has_key?(:user)
        guard_resource.cwd(command_opts[:cwd]) if command_opts.has_key?(:cwd)
        guard_resource.group(command_opts[:group]) if command_opts.has_key?(:group)
        guard_resource.environment(command_opts[:environment]) if command_opts.has_key?(:environment)
        guard_resource.timeout(command_opts[:timeout]) if command_opts.has_key?(:timeout)
        
        command_success = true

        # The run action will call into Mixlib::Shellout to execute
        # the script -- if a non-zero process status is returned, an
        # exception will be raised here
        begin
          guard_resource.run_action(:run)
        rescue Mixlib::ShellOut::ShellCommandFailed
          command_success = false
        end

        @last_command_succeeded = command_success
        command_success
      end

      def last_command_succeeded?
        @last_command_succeeded
      end

      protected

      def resource_class_from_id(node, resource_class_id)
        Chef::Platform.find_provider_for_node(node, resource_class_id)

        platform, version = Chef::Platform.find_platform_and_version(node)

        Chef::Resource.resource_for_platform(resource_class_id, platform, version)
      end
    end
  end
end

    
