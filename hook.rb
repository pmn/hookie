require 'sinatra'
require 'json'
require 'octokit'

# Set up octokit client
before do
  OCTOKIT_SECRET = ENV["GH_AUTH_TOKEN"]
  @client ||=Octokit::Client.new(:access_token => OCTOKIT_SECRET)
end

# Report the status of the commit back to the repository
def report_status(repo, sha, status, message)
  @client.create_status(repo, sha, status, :description => message)
end

# Various test functions
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

# Make sure a commit has a valid ticket number
# This responds to a PushEvent (https://developer.github.com/v3/activity/events/types/#pushevent)
post '/ticket-number' do
  payload = JSON.parse(request.body.read)
  commits = payload["commits"]
  repo_name = payload['repository']['full_name']
  head = payload['head_commit']

  # Set status to 'pending' before performing check
  report_status(repo_name, head["id"], 'pending', "Checking to see if there's a ticket number...")

  commits.each do |commit|
     if contains_ticket_number?(commit["message"])
       report_status(repo_name, commit["id"], 'success', "The commit message contained a ticket number.")
     else
       report_status(repo_name, commit["id"], 'failure', "The commit message was missing a ticket number.")
     end
  end

  # Report success
  status 200
end

# Make sure a Pull Request has 2 thumbs-up
# This responds to a PullRequestReviewCommentEvent (https://developer.github.com/v3/activity/events/types/#pullrequestreviewcommentevent)
post '/two-thumbs-up' do
  payload = JSON.parse(request.body.read)
  repo_name = payload['repository']['full_name']

  # Report success
  status 200
end
