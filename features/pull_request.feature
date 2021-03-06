Feature: hub pull-request
  Background:
    Given I am in "git://github.com/mislav/coral.git" git repo
    And I am "mislav" on github.com with OAuth token "OTOKEN"
    And the git commit editor is "vim"

  Scenario: Detached HEAD
    Given I am in detached HEAD
    When I run `hub pull-request`
    Then the stderr should contain "Aborted: not currently on any branch.\n"
    And the exit status should be 1

  Scenario: Non-GitHub repo
    Given the "origin" remote has url "mygh:Manganeez/repo.git"
    When I run `hub pull-request`
    Then the stderr should contain "Aborted: the origin remote doesn't point to a GitHub repository.\n"
    And the exit status should be 1

  Scenario: Create pull request respecting "insteadOf" configuration
    Given the "origin" remote has url "mygh:Manganeez/repo.git"
    When I successfully run `git config url."git@github.com:".insteadOf mygh:`
    Given the GitHub API server:
      """
      post('/repos/Manganeez/repo/pulls') {
        assert :base  => 'master',
               :head  => 'Manganeez:master',
               :title => 'here we go'
        json :html_url => "https://github.com/Manganeez/repo/pull/12"
      }
      """
    When I successfully run `hub pull-request -m "here we go"`
    Then the output should contain exactly "https://github.com/Manganeez/repo/pull/12\n"

  Scenario: With Unicode characters
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        halt 400 if request.content_charset != 'utf-8'
        assert :title => 'ăéñøü'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m ăéñøü`
    Then the output should contain exactly "the://url\n"

  Scenario: Invalid flag
    When I run `hub pull-request -yelp`
    Then the stderr should contain "unknown shorthand flag: 'y' in -yelp\n"
    And the exit status should be 1

  Scenario: With Unicode characters in the changelog
    Given the text editor adds:
      """
      I <3 encodings
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        halt 400 if request.content_charset != 'utf-8'
        assert :title => 'I <3 encodings',
               :body => 'ăéñøü'
        json :html_url => "the://url"
      }
      """
    Given I am on the "master" branch pushed to "origin/master"
    When I successfully run `git checkout --quiet -b topic`
    Given I make a commit with message "ăéñøü"
    And the "topic" branch is pushed to "origin/topic"
    When I successfully run `hub pull-request`
    Then the output should contain exactly "the://url\n"

  Scenario: Default message for single-commit pull request
    Given the text editor adds:
      """
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        halt 400 if request.content_charset != 'utf-8'
        assert :title => 'This is somewhat of a longish title that does not get wrapped & references #1234',
               :body => nil
        json :html_url => "the://url"
      }
      """
    Given I am on the "master" branch pushed to "origin/master"
    When I successfully run `git checkout --quiet -b topic`
    Given I make a commit with message "This is somewhat of a longish title that does not get wrapped & references #1234"
    And the "topic" branch is pushed to "origin/topic"
    When I successfully run `hub pull-request`
    Then the output should contain exactly "the://url\n"

  Scenario: Message template should include git log summary between base and head
    Given the text editor adds:
      """
      Hello
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        status 500
      }
      """
    Given I am on the "master" branch
    And I make a commit with message "One on master"
    And I make a commit with message "Two on master"
    And the "master" branch is pushed to "origin/master"
    Given I successfully run `git reset --hard HEAD~2`
    And I successfully run `git checkout --quiet -B topic origin/master`
    Given I make a commit with message "One on topic"
    And I make a commit with message "Two on topic"
    Given the "topic" branch is pushed to "origin/topic"
    And I successfully run `git reset --hard HEAD~1`
    When I run `hub pull-request`
    Given the SHAs and timestamps are normalized in ".git/PULLREQ_EDITMSG"
    Then the file ".git/PULLREQ_EDITMSG" should contain exactly:
      """
      Hello


# Requesting a pull to mislav:master from mislav:topic
#
# Write a message for this pull request. The first block
# of text is the title and the rest is the description.
#
# Changes:
#
# SHA1SHA (Hub, 0 seconds ago)
#    Two on topic
#
# SHA1SHA (Hub, 0 seconds ago)
#    One on topic

      """

  Scenario: Non-existing base
    Given the GitHub API server:
      """
      post('/repos/origin/coral/pulls') { 404 }
      """
    When I run `hub pull-request -b origin:master -m here`
    Then the exit status should be 1
    Then the stderr should contain:
      """
      Error creating pull request: Not Found (HTTP 404)
      Are you sure that github.com/origin/coral exists?
      """

  Scenario: Supplies User-Agent string to API calls
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        halt 400 unless request.user_agent.include?('Hub')
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m useragent`
    Then the output should contain exactly "the://url\n"

  Scenario: Text editor adds title and body
    Given the text editor adds:
      """
      This title comes from vim!

      This body as well.
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => 'This title comes from vim!',
               :body  => 'This body as well.'
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    When I successfully run `hub pull-request`
    Then the output should contain exactly "https://github.com/mislav/coral/pull/12\n"
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Text editor adds title and body with multiple lines
    Given the text editor adds:
      """


      This title is on the third line


      This body


      has multiple
      lines.

      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => 'This title is on the third line',
               :body  => "This body\n\n\nhas multiple\nlines."
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    When I successfully run `hub pull-request`
    Then the output should contain exactly "https://github.com/mislav/coral/pull/12\n"
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Text editor with custom commentchar
    Given git "core.commentchar" is set to "/"
    And the text editor adds:
      """
      # Dat title

      / This line is commented out.

      Dem body.
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => '# Dat title',
               :body  => 'Dem body.'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request`
    Then the output should contain exactly "the://url\n"

  Scenario: Failed pull request preserves previous message
    Given the text editor adds:
      """
      This title will fail
      """
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        halt 422 if params[:title].include?("fail")
        assert :body => "This title will fail",
               :title => "But this title will prevail"
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    When I run `hub pull-request`
    Then the exit status should be 1
    And the stderr should contain exactly:
      """
      Error creating pull request: Unprocessable Entity (HTTP 422)\n
      """
    Given the text editor adds:
      """
      But this title will prevail
      """
    When I successfully run `hub pull-request`
    Then the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Text editor fails
    Given the text editor exits with error status
    And an empty file named ".git/PULLREQ_EDITMSG"
    When I run `hub pull-request`
    Then the stderr should contain "error using text editor for pull request message"
    And the exit status should be 1
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Title and body from file
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => 'Title from file',
               :body  => "Body from file as well.\n\nMultiline, even!"
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    And a file named "pullreq-msg" with:
      """
      Title from file

      Body from file as well.

      Multiline, even!
      """
    When I successfully run `hub pull-request -F pullreq-msg`
    Then the output should contain exactly "https://github.com/mislav/coral/pull/12\n"
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Title and body from stdin
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => 'Unix piping is great',
               :body  => 'Just look at this ăéñøü'
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    When I run `hub pull-request -F -` interactively
    And I pass in:
      """
      Unix piping is great

      Just look at this ăéñøü
      """
    Then the output should contain exactly "https://github.com/mislav/coral/pull/12\n"
    And the exit status should be 0
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Title and body from command-line argument
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :title => 'I am just a pull',
               :body  => 'A little pull'
        json :html_url => "https://github.com/mislav/coral/pull/12"
      }
      """
    When I successfully run `hub pull-request -m "I am just a pull\n\nA little pull"`
    Then the output should contain exactly "https://github.com/mislav/coral/pull/12\n"
    And the file ".git/PULLREQ_EDITMSG" should not exist

  Scenario: Error when implicit head is the same as base
    Given I am on the "master" branch with upstream "origin/master"
    When I run `hub pull-request`
    Then the stderr should contain exactly:
      """
      Aborted: head branch is the same as base ("master")
      (use `-h <branch>` to specify an explicit pull request head)\n
      """

  Scenario: Explicit head
    Given I am on the "master" branch
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head => 'mislav:feature'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -h feature -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Explicit head with owner
    Given I am on the "master" branch
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head => 'mojombo:feature'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -h mojombo:feature -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Explicit base
    Given I am on the "feature" branch
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :base => 'develop'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -b develop -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Implicit base by detecting main branch
    Given the default branch for "origin" is "develop"
    And I am on the "master" branch
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :base => 'develop',
               :head => 'mislav:master'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Explicit base with owner
    Given I am on the "master" branch
    Given the GitHub API server:
      """
      post('/repos/mojombo/coral/pulls') {
        assert :base => 'develop'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -b mojombo:develop -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Explicit base with owner and repo name
    Given I am on the "master" branch
    Given the GitHub API server:
      """
      post('/repos/mojombo/coralify/pulls') {
        assert :base => 'develop'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -b mojombo/coralify:develop -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Error when there are unpushed commits
    Given I am on the "feature" branch with upstream "origin/feature"
    When I make 2 commits
    And I run `hub pull-request`
    Then the stderr should contain exactly:
      """
      Aborted: 2 commits are not yet pushed to origin/feature
      (use `-f` to force submit a pull request anyway)\n
      """

  Scenario: Ignore unpushed commits with `-f`
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head => 'mislav:feature'
        json :html_url => "the://url"
      }
      """
    When I make 2 commits
    And I successfully run `hub pull-request -f -m message`
    Then the output should contain exactly "the://url\n"

  Scenario: Pull request fails on the server
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        status 422
        json(:message => "I haz fail!")
      }
      """
    When I run `hub pull-request -m message`
    Then the stderr should contain exactly:
      """
      Error creating pull request: Unprocessable Entity (HTTP 422)
      I haz fail!\n
      """

  Scenario: Convert issue to pull request
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :issue => '92'
        json :html_url => "https://github.com/mislav/coral/pull/92"
      }
      """
    When I successfully run `hub pull-request -i 92`
    Then the output should contain exactly:
      """
      https://github.com/mislav/coral/pull/92
      Warning: Issue to pull request conversion is deprecated and might not work in the future.\n
      """

  Scenario: Convert issue URL to pull request
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :issue => '92'
        json :html_url => "https://github.com/mislav/coral/pull/92"
      }
      """
    When I successfully run `hub pull-request https://github.com/mislav/coral/issues/92`
    Then the output should contain exactly:
      """
      https://github.com/mislav/coral/pull/92
      Warning: Issue to pull request conversion is deprecated and might not work in the future.\n
      """

  Scenario: Enterprise host
    Given the "origin" remote has url "git@git.my.org:mislav/coral.git"
    And I am "mislav" on git.my.org with OAuth token "FITOKEN"
    And "git.my.org" is a whitelisted Enterprise host
    Given the GitHub API server:
      """
      post('/api/v3/repos/mislav/coral/pulls', :host_name => 'git.my.org') {
        assert :base => 'master',
               :head => 'mislav:master'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m enterprisey`
    Then the output should contain exactly "the://url\n"

  Scenario: Enterprise remote witch matching branch but no tracking
    Given the "origin" remote has url "git@git.my.org:mislav/coral.git"
    And I am "mislav" on git.my.org with OAuth token "FITOKEN"
    And "git.my.org" is a whitelisted Enterprise host
    And I am on the "feature" branch pushed to "origin/feature"
    Given the GitHub API server:
      """
      post('/api/v3/repos/mislav/coral/pulls', :host_name => 'git.my.org') {
        assert :base => 'master',
               :head => 'mislav:feature'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m enterprisey`
    Then the output should contain exactly "the://url\n"

  Scenario: Create pull request from branch on the same remote
    Given the "origin" remote has url "git://github.com/github/coral.git"
    And the "mislav" remote has url "git://github.com/mislav/coral.git"
    And I am on the "feature" branch pushed to "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/github/coral/pulls') {
        assert :base  => 'master',
               :head  => 'github:feature',
               :title => 'hereyougo'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Create pull request from branch on the personal fork case sensitive
    Given the "origin" remote has url "git://github.com/github/coral.git"
    And the "doge" remote has url "git://github.com/Mislav/coral.git"
    And I am on the "feature" branch pushed to "doge/feature"
    Given the GitHub API server:
      """
      post('/repos/github/coral/pulls') {
        assert :base  => 'master',
               :head  => 'Mislav:feature',
               :title => 'hereyougo'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Create pull request from branch on the personal fork
    Given the "origin" remote has url "git://github.com/github/coral.git"
    And the "doge" remote has url "git://github.com/mislav/coral.git"
    And I am on the "feature" branch pushed to "doge/feature"
    Given the GitHub API server:
      """
      post('/repos/github/coral/pulls') {
        assert :base  => 'master',
               :head  => 'mislav:feature',
               :title => 'hereyougo'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Create pull request to "upstream" remote
    Given the "upstream" remote has url "git://github.com/github/coral.git"
    And I am on the "master" branch pushed to "origin/master"
    Given the GitHub API server:
      """
      post('/repos/github/coral/pulls') {
        assert :base  => 'master',
               :head  => 'mislav:master',
               :title => 'hereyougo'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Open pull request in web browser
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -o -m hereyougo`
    Then "open the://url" should be run

  Scenario: Current branch is tracking local branch
    Given git "push.default" is set to "upstream"
    And I am on the "feature" branch with upstream "refs/heads/master"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :base  => 'master',
               :head  => 'mislav:feature'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Branch with quotation mark in name
    Given I am on the "feat'ure" branch with upstream "origin/feat'ure"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head  => "mislav:feat'ure"
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"

  Scenario: Pull request with assignee
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head  => "mislav:feature"
        json :html_url => "the://url", :number => 1234
      }
      patch('/repos/mislav/coral/issues/1234') {
        assert :assignee => "mislav", :labels => nil
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo -a mislav`
    Then the output should contain exactly "the://url\n"

  Scenario: Pull request with milestone
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head  => "mislav:feature"
        json :html_url => "the://url", :number => 1234
      }
      patch('/repos/mislav/coral/issues/1234') {
        assert :milestone => 1234
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo -M 1234`
    Then the output should contain exactly "the://url\n"

  Scenario: Pull request with labels
    Given I am on the "feature" branch with upstream "origin/feature"
    Given the GitHub API server:
      """
      post('/repos/mislav/coral/pulls') {
        assert :head  => "mislav:feature"
        json :html_url => "the://url", :number => 1234
      }
      patch('/repos/mislav/coral/issues/1234') {
        assert :labels => ["feature", "release"]
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo -l feature,release`
    Then the output should contain exactly "the://url\n"

  Scenario: Pull request to a fetch-only upstream
    Given the "upstream" remote has url "git://github.com/github/coral.git"
    And the "upstream" remote has push url "no_push"
    And I am on the "master" branch pushed to "origin/master"
    Given the GitHub API server:
      """
      post('/repos/github/coral/pulls') {
        assert :base  => 'master',
               :head  => 'mislav:master',
               :title => 'hereyougo'
        json :html_url => "the://url"
      }
      """
    When I successfully run `hub pull-request -m hereyougo`
    Then the output should contain exactly "the://url\n"
