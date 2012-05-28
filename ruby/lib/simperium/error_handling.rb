module ErrorHandling
    def self.handle_restclient_error(e)
        case e
        when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
          message = "Could not connect to Simperium (auth.simperium.com).  Please check your internet connection and try again.  If the problem continues, you should check Simperium's service status at https://simperium.com/, or let us know at contact@simperium.com."
        when SocketError
          message = "Unexpected error when trying to connect to Simpierum.  HINT: You may be seeing this message because your DNS is not working.  To check, try running 'host simperium.com' from the command line."
        else
          message = "Unexpected error communicating with Simperium.  If this problem persists, let us know at contact@simperium.com."
        end
        message += "\n\n(Network error: #{e.message})"
        raise StandardError.new(message)
    end

    def self.handle_api_error(rcode, rbody)
        message = rcode.to_s + ' '+ rbody
        raise StandardError.new(message)
    end
end