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

require 'chef/resource/script_guard/powershell_guard.rb'

class Chef
  class Resource
    module Guard
      module Powershell
        def powershell(command=nil)
          script_architecture = self.respond_to?(:architecture) ? self.architecture : nil
          PowershellGuard.new(node, command, script_architecture) if command
        end
      end
    end
  end
end



