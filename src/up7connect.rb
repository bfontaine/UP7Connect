#! /usr/bin/env ruby

#
# UP7Connect
# ----------
# Repository: github.com/bfontaine/UP7Connect
# License: MIT
# Author: Baptiste Fontaine
#

require "uri"
require "net/http"
require "yaml"
require "io/console"
require "openssl"
require "pathname"

class FileDoesNotExists < Exception;end

module Up7Connect
  class << self
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

    def version
        "0.1.0b"
    end

    def login=(credentials)

        credentials = credentials.take(2)
        filename = login_filepath

        File.open(filename, "w") do |f|
            f.write YAML.dump(credentials)
        end

        File.chmod(0600, filename)

        credentials
    end

    def credentials_file
      @credentials_file ||= Pathname.new(File.expand_path("~/.up7connect.conf"))
    end

    def credentials
      @credentials ||=
        if credentials_file.exist?
          load_credentials
        else
          puts "Missing login/password file. Please fill your informations."
          ask_credentials
        end
    end

    def wlan?
        case RUBY_PLATFORM
        when /linux/
            scan = `iwlist wlan0 scan last`;
            essid = /ESSID:"([^"]+)"/.match(scan)#.captures

            return false if essid.nil? || essid.captures.length == 0

            essid.captures[0] === "up7c"
        else
          true
        end
    end

    def connect(verbose=true)
      uri = URI("https://1.1.1.1/login.html")

      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(
          "buttonClicked" => 4,
          "err_flag" => 0,
          "redirect_url" => "",
          "username" => credentials[:user],
          "password" => credentials[:password],
      )
      req["User-Agent"] = "UP7Connect (v#{version})"

      # &ap_mac=00:11:22:33:44
      req["Referer"] = "https://1.1.1.1/fs/customwebauth/login.html?" + \
                      "switch_url=https://1.1.1.1/login.html&wlan=up7d"

      begin
        resp = Net::HTTP.start(uri.host, uri.port,
                                :use_ssl => (uri.scheme == "https"),
                                :verify_mode => OpenSSL::SSL::VERIFY_NONE,
                                :open_timeout => 5) do |http|
            http.request(req)
        end
      rescue Timeout::Error
        puts "Timeout." if verbose
        false
      rescue Errno::ENETUNREACH
        puts "Net unreachable." if verbose
        false
      else
        if (resp.code != "200" && resp.code != 200)
          puts "Connection failed (HTTP code: #{resp.code})"
          return false
        end

        if (resp.body.include? "You are already logged in.")
          puts "Already connected." if verbose
          return true
        end
        # "The User Name and Password combination you have entered is invalid.
        # Please try again."
        if (resp.body.include? "have entered is invalid. Please try again.")
          puts "Bad login/password." if verbose
          return false
        end

        puts "Connection ok." if verbose
        true
      end
    end

    def main(verbose=true)
      unless Up7Connect.wlan?
        puts "It seems that up7c ESSID is not accessible here..."
        exit 1
      end
      exit (connect(verbose) ? 0 : 1)
    end

    private

    def load_credentials
      YAML.load_file credentials_file
    end

    def ask_credentials
      credentials = {}
      print "Login: "
      credentials[:user] = gets.chomp
      print "Password (hidden): "
      credentials[:password] = STDIN.noecho(&:gets).chomp
      puts

      credentials_file.open("w") do |file|
        file.write credentials.to_yaml
      end
      credentials
    end
  end
end


if $0 == __FILE__
  if ARGV.empty?
      Up7Connect.main
  else
    case ARGV[0]
    when "-h", "-help", "--help"
      puts Up7Connect.USAGE
    when "-s", "-set", "--set"
      Up7Connect.asklogin
    when "-v", "-version", "--version"
      puts "UP7Connect v#{Up7Connect.version}"
    when "-q", "-quiet", "--quiet"
      Up7Connect.main false
    else
      puts "#{ARGV[0]} : not a valid option"
      puts Up7Connect.USAGE
    end
  end
end
