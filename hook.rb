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
  repo_name = payload["repository"]["full_name"]
  head = payload["head_commit"]["id"]

  # Set status to 'pending' before performing check
  report_status(repo_name, head, "pending", "Checking to see if there's a ticket number...")

  commits.each do |commit|
     if contains_ticket_number?(commit["message"])
       report_status(repo_name, commit["id"], "success", "The commit message contained a ticket number.")
     else
       report_status(repo_name, commit['id'], "failure", "The commit message was missing a ticket number.")
     end
  end

  # Report success
  status 200
end

# Make sure a Pull Request has 2 thumbs-up
# This responds to an IssueCommentEvent(https://developer.github.com/v3/activity/events/types/#issuecommentevent)
post '/two-thumbs-up' do
  payload = JSON.parse(request.body.read)
  repo_name = payload["repository"]["full_name"]
  issue_number = payload["issue"]["number"]

  pull_request = @client.pull_request(repo_name, issue_number)
  issue_comments = @client.issue_comments(repo_name, issue_number)

  # Set status to 'pending' before performing any checks
  report_status(repo_name, pull_request.head.sha, "pending", "Checking for thumbs-ups...")

  # Check to see if there are at least 2 thumbs-up emoji in the PR comments
  thumbs_ups = 0
  issue_comments.each do |comment|
    if comment.body.include?(":+1:") or comment.body.include?(":thumbsup:")
      thumbs_ups += 1
    end
  end

  if thumbs_ups >= 2
    report_status(repo_name, pull_request.head.sha, "success", "This has enough approvals to merge.")
  else
    report_status(repo_name, pull_request.head.sha, "failure", "There are not enough thumbs-ups (2 required).")
  end

  # Report success
  status 200
end
