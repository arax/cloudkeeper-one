require 'thor'
require 'yell'

module Cloudkeeper
  module One
    class CLI < Thor
      class_option :'logging-level',
                   required: true,
                   default: Cloudkeeper::One::Settings['logging']['level'],
                   type: :string,
                   enum: Yell::Severities
      class_option :'logging-file',
                   default: Cloudkeeper::One::Settings['logging']['file'],
                   type: :string,
                   desc: 'File to write logs to'
      class_option :debug,
                   default: Cloudkeeper::One::Settings['debug'],
                   type: :boolean,
                   desc: 'Runs cloudkeeper in debug mode'

      method_option :'listen-address',
                    required: true,
                    default: Cloudkeeper::One::Settings['listen-address'],
                    type: :string,
                    desc: 'IP address gRPC server will listen on'
      method_option :identifier,
                    required: true,
                    default: Cloudkeeper::One::Settings['identifier'],
                    type: :string,
                    desc: 'Instance identifier'
      method_option :'appliances-tmp-dir',
                    required: true,
                    default: Cloudkeeper::One::Settings['appliances']['tmp-dir'],
                    type: :string,
                    desc: 'Directory where to temporarily store appliances'
      method_option :'appliances-template-dir',
                    required: false,
                    default: Cloudkeeper::One::Settings['appliances']['template-dir'],
                    type: :string,
                    desc: 'If set, templates within this directory are used to construct images and templates in OpenNebula'
      method_option :'appliances-permissions',
                    required: true,
                    default: Cloudkeeper::One::Settings['appliances']['permissions'],
                    type: :string,
                    desc: 'UNIX-like permissions appliances will have within OpenNebula'
      method_option :'opennebula-secret',
                    required: true,
                    default: Cloudkeeper::One::Settings['opennebula']['secret'],
                    type: :string,
                    desc: 'OpenNebula authentication secret'
      method_option :'opennebula-endpoint',
                    required: true,
                    default: Cloudkeeper::One::Settings['opennebula']['endpoint'],
                    type: :string,
                    desc: 'OpenNebula XML-RPC endpoint'
      method_option :'opennebula-datastores',
                    required: true,
                    default: Cloudkeeper::One::Settings['opennebula']['datastores'],
                    type: :array,
                    desc: 'OpenNebula datastores images will be uploaded to'
      method_option :'opennebula-groups',
                    required: false,
                    default: Cloudkeeper::One::Settings['opennebula']['groups'],
                    type: :array,
                    desc: 'If set, appliances will be registered under these groups instead of the one from image list'
      method_option :'opennebula-users',
                    required: false,
                    default: Cloudkeeper::One::Settings['opennebula']['users'],
                    type: :array,
                    desc: 'Handle only images/templates of specified users'
      method_option :'opennebula-api-call-timeout',
                    required: true,
                    default: Cloudkeeper::One::Settings['opennebula']['api-call-timeout'],
                    type: :string,
                    desc: 'How long will cloudkeeper-one wait for image/template operations to finish in OpenNebula'

      desc 'sync', 'Runs synchronization process'
      def sync
        initialize_sync options
        grpc_server = GRPC::RpcServer.new
        grpc_server.add_http2_port Cloudkeeper::One::Settings[:'listen-address'], :this_port_is_insecure
        grpc_server.handle Cloudkeeper::One::CoreConnector
        grpc_server.run_till_terminated
        # TODO: interrupt catching
      end

      desc 'version', 'Prints cloudkeeper version'
      def version
        $stdout.puts Cloudkeeper::One::VERSION
      end

      default_task :sync

      private

      def initialize_sync(options)
        initialize_configuration options
        initialize_logger
        logger.debug "cloudkeeper-one 'sync' called with parameters: #{Cloudkeeper::One::Settings.to_hash.inspect}"
      end

      def initialize_configuration(options)
        Cloudkeeper::One::Settings.clear
        Cloudkeeper::One::Settings.merge! options.to_hash

        gem_dir = File.realdirpath(File.join(File.dirname(__FILE__), '..'))
        Cloudkeeper::One::Settings[:'appliances-template-dir'] = File.join(gem_dir, 'config', 'templates') \
          unless Cloudkeeper::One::Settings[:'appliances-template-dir']
      end

      # Inits logging according to the settings
      #
      # @option parameters [String] logging-level
      # @option parameters [String] logging-file file to log to
      # @option parameters [TrueClass, FalseClass] debug debug mode
      def initialize_logger
        Cloudkeeper::One::Settings[:'logging-level'] = 'DEBUG' if Cloudkeeper::One::Settings[:debug]

        logging_file = Cloudkeeper::One::Settings[:'logging-file']
        logging_level = Cloudkeeper::One::Settings[:'logging-level']

        Yell.new :stdout, name: Object, level: logging_level.downcase, format: Yell::DefaultFormat
        Object.send :include, Yell::Loggable

        setup_file_logger(logging_file) if logging_file

        logger.debug 'Running in debug mode...'
      end

      def setup_file_logger(logging_file)
        unless (File.exist?(logging_file) && File.writable?(logging_file)) || File.writable?(File.dirname(logging_file))
          logger.error "File #{logging_file} isn't writable"
          return
        end

        logger.adapter :file, logging_file
      end
    end
  end
end