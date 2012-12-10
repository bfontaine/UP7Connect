#! /usr/bin/ruby1.9.1

#
# UP7Connect
# ----------
# Repository: github.com/bfontaine/UP7Connect
# License: MIT
# Author: Baptiste Fontaine
#

require 'uri'
require 'net/http'
require 'yaml'

class FileDoesNotExists < Exception
end

module Up7Connect

    @@USAGE = <<-EOS

Usage : ./up7connect.rb <option>

<option> :
        -s,-set,--set
            Set login/password.

        -h,-help,--help
            Print this help and exit.

        -v,-version,--version
            Print UP7Connect version and exit.

Without <action> : Connect to 'up7d' wireless network, using saved login/password.
    EOS

    def self::os()

        oses = {
            :linux   => [ 'linux' ],
            :osx     => [ 'darwin' ],
            :bsd     => [ 'bsd' ],
            :windows => [ 'win32', 'win64' ]
        }

        oses.each do |key, strs|

            strs.each do |s|
                return key unless RUBY_PLATFORM.index(s).nil?
            end

        end

    end

    def self::version()
        '0.1.0b'
    end

    def self::login_filepath(os=nil)

        os ||= self::os

        paths = {
            '~/.up7connect.conf'  => [ :linux, :osx, :bsd ],
            '.\\.up7connect.conf' => [ :windows ] # TODO
        }

        paths.each do |path, oses|
            return File.expand_path(path) if oses.include? os
        end

        return File.expand_path('./.up7connect.conf') # default
    end

    def self::login=( credentials )

        credentials = credentials.take(2)
        filename = self::login_filepath

        File.open(filename, 'w') do |f|
            f.write YAML.dump(credentials)
        end

        File.chmod(0600, filename)

        credentials
    end

    def self::login()

        filename = self::login_filepath

        return nil unless File.exist?(filename)

        YAML.load(File.read(filename))
    end

    def self::asklogin
        print 'Login: '
        u = gets.chomp
        print 'Password: '
        p = gets.chomp
        self::login = [u, p]
    end

    def self::wlan?
        
        os = self::os

        if os === :linux
            scan = `iwlist wlan0 scan last`;
            essid = /ESSID:"([^"]+)"/.match(scan)#.captures

            return false if (essid.nil? || (essid.captures.length == 0))
            
            return (essid.captures[0] === 'up7c')

        elsif os === :bsd

            #TODO

        end

        return true # TODO
    end

    # TODO see [FR] :
    # http://www.crium.univ-metz.fr/reseau/wifi/faq/diagnostic.html
    #def Up7Connect.is_connected?
        #begin
            #puts "D: trying to ping 5 times kernel.org" if (@@debug_mode)
            #`ping -q -c 5 -W 2 kernel.org`
        #rescue Errno::ENETUNREACH
            #puts 'D: Error, Net Unreachable' if (@@debug_mode)
            #return false
        #rescue Errno::EHOSTUNREACH
            #puts 'D: Error, Host Unreachable' if (@@debug_mode)
            #return false
        #end
        #return ($?.exitstatus === 0)
    #end

    def self::connect(verbose=true)

        user, passwd = self::login

        uri = URI('https://1.1.1.1/login.html')

        req = Net::HTTP::Post.new(uri.path)
        req.set_form_data(
            'buttonClicked' => 4,
            'err_flag' => 0,
            'redirect_url' => '',
            'username' => user,
            'password' => passwd
        )
        req['User-Agent'] = "UP7Connect (v#{self::version})"

        # &ap_mac=00:11:22:33:44
        req['Referer'] = 'https://1.1.1.1/fs/customwebauth/login.html?' \
                       +'switch_url=https://1.1.1.1/login.html&wlan=up7d'

        begin
            resp = Net::HTTP.start(uri.host, uri.port,
                                   :use_ssl => (uri.scheme == 'https'),
                                   :verify_mode => OpenSSL::SSL::VERIFY_NONE,
                                   :open_timeout => 5) do |http|
                http.request(req)
            end

        rescue Timeout::Error
            puts 'Timeout.' if verbose
            return false
        rescue Errno::ENETUNREACH
            puts 'Net unreachable.' if verbose
            return false
        else
            if (resp.code != '200' && resp.code != 200)
                puts "Connection failed (HTTP code: #{resp.code})"
                return false
            end

            if (resp.body.include? 'You are already logged in.')
                puts 'Already connected.' if verbose
                return true
            end
            # "The User Name and Password combination you have
            # entered is invalid. Please try again."
            if (resp.body.include? 'have entered is invalid. Please try again.')
                puts 'Bad login/password.' if verbose
                return false
            end

            puts 'Connection ok.' if verbose
            return true
        end
    end

    def Up7Connect.main
        if self::login.nil?
            puts 'Missing login/password file. Please fill your informations.'
            self::asklogin
        end

        if (!Up7Connect.wlan?)
            puts "It seems that up7c ESSID is not accessible here..."
            exit -1
        end
        #if (Up7Connect.is_connected?)
        #    puts 'Already connected.' if (@@verbose_mode || @@debug_mode)
        #    exit 0
        #end
        exit(connect ? 0 : 1)
    end
end


if $0 == __FILE__
    if (ARGV.length == 0)
        Up7Connect.main
    else
        case ARGV[0]

        when '-h','-help','--help' # help
            puts USAGE

        when '-s','-set','--set' # config
            Up7Connect.asklogin

        when '-v','-version','--version' # version
            puts "UP7Connect v#{Up7Connect.version}"

        when '-q','-quiet','--quiet' # quiet mode
            Up7Connect.main(false)
        else
            puts "#{ARGV[0]} : not a valid option"
            puts Up7Connect.USAGE
        end
    end
end
