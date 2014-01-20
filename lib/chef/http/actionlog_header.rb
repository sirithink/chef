class Chef
  class HTTP
    class ActionlogHeader

      def initialize(opts={})
        Chef::Log.info(opts[:run_id])
        @run_id = opts[:run_id]
      end

      def handle_request(method, url, headers={}, data=false)
        headers.merge!({'X-Ops-Reporting-Remote-Action-Log' => @run_id}) if run_id?
        [method, url, headers, data]
      end

      def handle_response(http_response, rest_request, return_value)
        [http_response, rest_request, return_value]
      end

      def run_id?
        if @run_id
          true
        else
          false
        end
      end

    end
  end
end
