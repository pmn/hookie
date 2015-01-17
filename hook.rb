require 'sinatra'
require 'json'
require 'octokit'

# Set up octokit client
before do
  OCTOKIT_SECRET = ENV["GH_AUTH_TOKEN"]
  @client ||=Octokit::Client.new(:access_token => OCTOKIT_SECRET)
end


# Handle a commit and make sure it has a valid ticket number
post '/ticket-number' do
  payload = JSON.parse(request.body.read)
  commits = payload["commits"]
  repo = payload['repository']['full_name']

  commits.each do |commit|
     if contains_ticket_number?(commit["message"])
       report_status(repo, commit, 'success', "The commit message contained a ticket number.")
     else
       report_status(repo, commit, 'failure', "The commit message was missing a ticket number.")
     end
  end

  # Report success
  status 200
end

def contains_ticket_number?(message)
  valid_tickets = ["BUG-1","BUG-2","FEATURE-3","FEATURE-4","FEATURE-5"]

  re = /\[(.*?)\]/
  match = message.match re

  if match.nil?
    false
  else
    valid_tickets.include? match[1]
  end
end

# Report the status of the commit back to the repository
def report_status(repo, commit, status, message)
  @client.create_status(repo, commit['id'], status, :description => message)
end
