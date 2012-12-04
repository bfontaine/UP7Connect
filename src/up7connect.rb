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

class Up7FileDoesNotExists < Exception
end

module Up7Connect

    @@OS = lambda {
            return :linux if (/linux/i =~ RUBY_PLATFORM)
            return :mac_os if (/darwin/i =~ RUBY_PLATFORM)
            return :bsd if (/bsd/i =~ RUBY_PLATFORM)
            return :ms_windows if (/win(32|64)/i =~ RUBY_PLATFORM)
            :default
    }.call

    @@UP7C_VERSION = '0.1b'

    @@LOGIN_FILEPATH = { :linux => '~/.up7connect.conf',
                         :mac_os => '~/.up7connect.conf',
                         :bsd => '~/.up7connect.conf',
                         :default => '~/.up7connect.conf',
                         :ms_windows => '.\\.up7connect.conf' # TODO
                       }
    @@LOGIN_JOIN = '__up7c__'

    @@ESSID = 'up7d'
    @@LOGIN_PAGE = 'https://1.1.1.1/login.html'
    @@UA = "UP7Connect (v#{@@UP7C_VERSION})"
    # &ap_mac=00:11:22:33:44
    @@REFERER_HEADER = 'https://1.1.1.1/fs/customwebauth/login.html?'\
                       +'switch_url=https://1.1.1.1/login.html&wlan=up7d'

    @@OPEN_TIMEOUT = 5
    
    @@PING_TIMEOUT = 2
    @@PING_COUNT = 5
    @@PING_SERVER = 'kernel.org'
    
    @@verbose_mode = true
    @@debug_mode = false

    attr_accessor :verbose_mode, :debug_mode

    @@USAGE = <<-EOS

Usage : ./up7connect.rb <option>

<option> :
        -s,-set,--set
            Set login/password.

        -h,-help,--help
            Print this help and exit.

        -v,-version,--version
            Print UP7Connect version (#{@@UP7C_VERSION}) and exit.

Without <action> : Connect to 'up7d' wireless network, using saved login/password.
    EOS

    def Up7Connect.loginfile_exists?
        return File.exist?(File.expand_path(@@LOGIN_FILEPATH[@@OS]))
    end

    def Up7Connect.getlogin
        if (!loginfile_exists?)
            puts 'D: login/password file missing.' if (debug_mode)
            raise Up7FileDoesNotExists
        end
        file = File.open(File.expand_path(@@LOGIN_FILEPATH[@@OS]), 'r')
        content = file.read.gsub(/([^a-z])/) {|e| ((e.ord)-33).to_s}
        file.close
        s1 = ''
        s2 = ''
        content.split(/\D/).each {|e| s1 << e.to_i.chr}
        s1 = s1.split /\D/
            s1.each {|e| s2 << e.to_i.chr}
        s2.split @@LOGIN_JOIN
    end

    def Up7Connect.setlogin(u,p)
        s = [u,p].join @@LOGIN_JOIN
        j1 = (rand(122-97)+97).chr
        j2 = (rand(122-97)+97).chr
        e1 = []
        e2 = []
        s.each_byte {|c| e1 << c.ord}
        e1.join(j1).each_byte {|c| e2 << c.ord}
        file = File.open(File.expand_path(@@LOGIN_FILEPATH[@@OS]), 'w')
        file.write e2.join(j2).gsub(/(\d)/) {|e| (33+e.to_i).chr}
        file.chmod(0600) if ([:linux,:bsd,:max_os].include? @@OS)
        file.close
    end

    def Up7Connect.asklogin
        print 'Login: '
        u = gets.chomp
        print 'Password: '
        p = gets.chomp
        setlogin(u,p)
    end

    # TODO see [FR] :
    # http://www.crium.univ-metz.fr/reseau/wifi/faq/diagnostic.html
    #def Up7Connect.is_connected?
        #begin
            #puts "D: trying to ping #{@@PING_COUNT} times #{@@PING_SERVER}" if (@@debug_mode)
            #`ping -q -c #{@@PING_COUNT} -W #{@@PING_TIMEOUT} #{@@PING_SERVER}`
        #rescue Errno::ENETUNREACH
            #puts 'D: Error, Net Unreachable' if (@@debug_mode)
            #return false
        #rescue Errno::EHOSTUNREACH
            #puts 'D: Error, Host Unreachable' if (@@debug_mode)
            #return false
        #end
        #return ($?.exitstatus === 0)
    #end

    def Up7Connect.wlan_is_present?
        if @@OS === :linux
            scan = `iwlist wlan0 scan last`;
            essid = /ESSID:"([^"]+)"/.match(scan)#.captures
            return false if (essid.nil? || (essid.captures.length == 0))
            return (essid.captures[0] === @@ESSID)
        elsif @@OS === :bsd
            #TODO
        end

        return true # quick'n'dirty solution
    end

    def Up7Connect.connect

        user, passwd = getlogin

        uri = URI(@@LOGIN_PAGE)

        req = Net::HTTP::Post.new(uri.path)
        req.set_form_data(
            'buttonClicked' => 4,
            'err_flag' => 0,
            'redirect_url' => '',
            'username' => user,
            'password' => passwd
        )
        req['User-Agent'] = @@UA
        req['Referer'] = @@REFERER_HEADER

        begin
            resp = Net::HTTP.start(uri.host, uri.port,
                                   :use_ssl => (uri.scheme == 'https'),
                                   :verify_mode => OpenSSL::SSL::VERIFY_NONE,
                                   :open_timeout => @@OPEN_TIMEOUT
                                  ) { |http| http.request(req) }
        rescue Timeout::Error
            puts 'Timeout.' if (@@verbose_mode || @@debug_mode)
            return false
        rescue Errno::ENETUNREACH
            puts 'Net unreachable.' if (@@verbose_mode || @debug_mode)
            return false
        else
            if (resp.code != '200' && resp.code != 200)
                puts "Connection failed (HTTP code: #{resp.code})"
                return false
            end

            if (resp.body.include? 'You are already logged in.')
                puts 'Already connected.' if (@@verbose_mode || @@debug_mode)
                return true
            end
            # "The User Name and Password combination you have
            # entered is invalid. Please try again."
            if (resp.body.include? 'have entered is invalid. Please try again.')
                puts 'Bad login/password.' if (@@verbose_mode || @@debug_mode)
                return false
            end

            puts 'Connection ok.' if (@@verbose_mode || @@debug_mode)
            return true
        end
    end

    def Up7Connect.main
        if (!loginfile_exists?)
            puts 'Missing login/password file. Please fill your informations.'
            asklogin
        end

        if (!Up7Connect.wlan_is_present?)
            puts "It seems that #{@@ESSID} ESSID is not accessible here..."
            exit -1
        end
        #if (Up7Connect.is_connected?)
        #    puts 'Already connected.' if (@@verbose_mode || @@debug_mode)
        #    exit 0
        #end
        exit(connect ? 0 : 1)
    end
end


if /up7connect\.rb/ =~__FILE__
    if (ARGV.length == 0)
        Up7Connect.main
    else
        case ARGV[0]

        when '-h','-help','--help' # help
            puts USAGE

        when '-s','-set','--set' # config
            Up7Connect.asklogin

        when '-v','-version','--version' # version
            puts "UP7Connect v#{Up7Connect.UP7C_VERSION}"

        when '-q','-quiet','--quiet' # quiet mode
            Up7Connect.verbose_mode = false
            Up7Connect.debug_mode = false
            Up7Connect.main
        else
            puts "#{ARGV[0]} : not a valid option"
            puts Up7Connect.USAGE
        end
    end
end
