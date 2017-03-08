require 'securerandom'

module Cloudkeeper
  module One
    module ApplianceActions
      module Utils
        module ImageDownload
          def download_image(uri, username, password)
            filename = generate_filename
            retrieve_image URI.parse(uri), username, password, filename

            filename
          rescue URI::InvalidURIError => ex
            raise Cloudkeeper::One::Errors::NetworkConnectionError, ex
          end

          private

          def retrieve_image(uri, username, password, filename)
            Net::HTTP.start(uri.host, uri.port) do |http|
              request = Net::HTTP::Get.new(uri)
              request.basic_auth username, password

              http.request(request) do |response|
                response.value
                open(filename, 'w') { |file| response.read_body { |chunk| file.write(chunk) } }
              end
            end
          rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse,
                 Net::HTTPServerException, Net::HTTPHeaderSyntaxError, Net::ProtocolError => ex
            raise Cloudkeeper::One::Errors::NetworkConnectionError, ex
          end

          def generate_filename
            File.join(Cloudkeeper::One::Settings[:'appliances-tmp-dir'], SecureRandom.uuid)
          end
        end
      end
    end
  end
end