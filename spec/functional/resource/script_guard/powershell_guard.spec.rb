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

require 'spec_helper'

describe Chef::Resource::WindowsScript::PowershellScript, :windows_only do

  include_context Chef::Resource::WindowsScript

  let(:successful_executable_script_content) { "#{ENV['SystemRoot']}\\system32\\attrib.exe $env:systemroot" }
  let(:windows_process_exit_code_success_content) { "#{ENV['SystemRoot']}\\system32\\attrib.exe $env:systemroot" }  
  let(:windows_process_exit_code_not_found_content) { "findstr /notavalidswitch" }  
  let!(:resource) do
    r = Chef::Resource::WindowsScript::PowershellScript.new("PowershellGuard functional test", @run_context)
    r.code(successful_executable_script_content)
    r
  end

  before(:each) do
    resource.not_if.clear
    resource.only_if.clear
  end

  it "evaluates a not_if block using powershell.exe" do
    resource.not_if :powershell_script, "exit([int32](![System.Environment]::CommandLine.Contains('powershell.exe')))"
    resource.should_skip?(:run).should be_true
  end

  it "evaluates an only_if block using powershell.exe" do
    resource.only_if :powershell_script, "exit([int32](![System.Environment]::CommandLine.Contains('powershell.exe')))"
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a not_if block as false" do
    resource.not_if { false }
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a not_if block as true" do
    resource.not_if { true }
    resource.should_skip?(:run).should be_true
  end

  it "evaluates an only_if block as false" do
    resource.only_if { false }
    resource.should_skip?(:run).should be_true
  end

  it "evaluates an only_if block as true" do
    resource.only_if { true }
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a non-zero powershell exit status for not_if as true" do
    resource.not_if :powershell_script, "exit 37"
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a zero powershell exit status for not_if as false" do
    resource.not_if :powershell_script, "exit 0"
    resource.should_skip?(:run).should be_true
  end

  it "evaluates a failed executable exit status for not_if as false" do
    resource.not_if :powershell_script, windows_process_exit_code_not_found_content
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a successful executable exit status for not_if as true" do
    resource.not_if :powershell_script, windows_process_exit_code_success_content
    resource.should_skip?(:run).should be_true
  end

  it "evaluates a failed executable exit status for only_if as false" do
    resource.only_if :powershell_script, windows_process_exit_code_not_found_content
    resource.should_skip?(:run).should be_true
  end

  it "evaluates a successful executable exit status for only_if as true" do
    resource.only_if :powershell_script, windows_process_exit_code_success_content
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a failed cmdlet exit status for not_if as true" do
    resource.not_if :powershell_script, "throw 'up'"
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a successful cmdlet exit status for not_if as true" do
    resource.not_if :powershell_script, "cd ."
    resource.should_skip?(:run).should be_true
  end

  it "evaluates a failed cmdlet exit status for only_if as false" do
    resource.only_if :powershell_script, "throw 'up'"
    resource.should_skip?(:run).should be_true
  end

  it "evaluates a successful cmdlet exit status for only_if as true" do
    resource.only_if :powershell_script, "cd ."
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a not_if block using the cwd guard parameter" do
    custom_cwd = "#{ENV['SystemRoot']}\\system32\\drivers\\etc"
    resource.not_if :powershell_script, "exit ! [int32]($pwd.path -eq #{custom_cwd})", :cwd => custom_cwd
    resource.should_skip?(:run).should be_true
  end
  
  it "evaluates an only_if block using the cwd guard parameter" do
    custom_cwd = "#{ENV['SystemRoot']}\\system32\\drivers\\etc"
    resource.only_if :powershell_script, "exit ! [int32]($pwd.path -eq #{custom_cwd})", :cwd => custom_cwd
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a 64-bit resource with a 64-bit guard and interprets boolean false as zero status code", :windows64_only do
    resource.architecture :x86_64
    resource.only_if :powershell_script, "exit [int32]($env:PROCESSOR_ARCHITECTURE -ne 'AMD64')"
    resource.should_skip?(:run).should be_false
  end  

  it "evaluates a 64-bit resource with a 64-bit guard and interprets boolean true as nonzero status code", :windows64_only do
    resource.architecture :x86_64
    resource.only_if :powershell_script, "exit [int32]($env:PROCESSOR_ARCHITECTURE -eq 'AMD64')"
    resource.should_skip?(:run).should be_true
  end  
  
  it "evaluates a 32-bit resource with a 32-bit guard and interprets boolean false as zero status code" do
    resource.architecture :i386
    resource.only_if :powershell_script, "exit [int32]($env:PROCESSOR_ARCHITECTURE -ne 'X86')"
    resource.should_skip?(:run).should be_false
  end

  it "evaluates a 32-bit resource with a 32-bit guard and interprets boolean true as nonzero status code" do
    resource.architecture :i386
    resource.only_if :powershell_script, "exit [int32]($env:PROCESSOR_ARCHITECTURE -eq 'X86')"
    resource.should_skip?(:run).should be_true
  end
end
