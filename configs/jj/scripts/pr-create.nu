#!/usr/bin/env nu
# jj-pr-create — push @- to a new bookmark and open a GitHub PR.
# Usage (via jj alias): jj pr-create [bookmark-name]
#   If bookmark-name is omitted it is inferred from the @- commit description.

def main [...args: string] {

    let dirty = jj diff -r @ --summary --color never
    if ($dirty | is-not-empty) {
        print $"Working copy \(@\) has uncommitted changes:\n($dirty)"
        let answer = (input "Commit them before opening the PR? [y/N] " | str downcase | str trim)
        if $answer == "y" {
            jj commit
        }
    }
    let desc = jj log -r "@-" --no-graph --color never -T 'description'
    if ($desc | is-empty) {
        error make { msg: "The @- commit has an empty description (needed for PR title)." }
    }
    let title = $desc | lines | first

    let bookmark = if ($args | length) > 0 {
        $args | first
    } else {
        let parsed = ($title | parse "{scope}: {verb} {rest}")
        if ($parsed | is-empty) {
            error make { msg: $"Cannot parse description '($title)' — expected 'scope: verb rest' format." }
        }
        let scope = ($parsed | first | get scope)
        let rest  = ($parsed | first | get rest)

        let raw = (
            input $"Kind for scope '($scope)'? [feat]/fix/refactor/dev/docs: "
            | str trim
        )
        let kind = if ($raw | is-empty) { "feat" } else { $raw }

        # Take the first 6 words, join with hyphens.
        let slug = (
            $rest
            | str downcase
            | str replace --all --regex '[^a-z0-9 ]' ''
            | split row ' '
            | where { |w| ($w | str length) > 0 }
            | take 6
            | str join '-'
        )

        # Optional issue-number suffix (#NNN anywhere in the description)
        let issue_matches = ($desc | parse --regex '#(?P<num>\d+)')
        let suffix = if ($issue_matches | length) > 0 {
            $"-($issue_matches | first | get num)"
        } else {
            ""
        }

        $"($kind)/($scope)/($slug)($suffix)"
    }

    let remotes = (
        jj git remote list
        | lines
        | each { |l| $l | split row ' ' | { name: ($in | first), url: ($in | last) } }  
    )
    print $"Available remotes: ($remotes | each { |r| $r.name } | str join ', ')"

    mut remote = null
    loop {
        let remote_input = (input "Remote (default origin)? " | str trim)
        let name = if ($remote_input | is-empty) { "origin" } else { $remote_input }
        let found = ($remotes | where { |r| $r.name == $name })
        if ($found | is-not-empty) {
           $remote = $name
           break
        }
        print $"Unknown remote '($name)'"
    }

    let remote_url = (
        $remotes
        | where { |r| $r.name == $remote }
        | first
        | get url
    )

    let repo = (
        $remote_url
        | parse --regex '(?:github\.com[:/])(?P<repo>[^/]+/[^/]+)'
        | first
        | get repo
        | str replace --regex '\.git$' ''
    )

    let default_branch = (
        ^gh api $"repos/($repo)" --jq '.default_branch'
    )

    let base_input = (input $"Base branch \(default: ($default_branch)\)?" | str trim)
    let base = if ($base_input | is-empty) { $default_branch } else { $base_input }

    let template_path = $"(jj root)/.github/pull_request_template.md"
    let body = if ($template_path | path exists) {
        open --raw $template_path
    } else {
      ""
    }

    mut is_draft = (input "Mark as draft? [y/N] " | str downcase | str trim)
    if ($is_draft | is-empty) { $is_draft = "y" }
    let draft = ($is_draft == "y")

    print $"\n→ Bookmark : ($bookmark)"
    print $"→ Remote   : ($remote)"
    print $"→ Repo     : ($repo)"
    print $"→ Base     : ($base)"
    print $"→ Title    : ($title)"
    print $"→ Draft    : ($draft)"
    mut confirm = (input "Push and open PR? [y/N] " | str downcase | str trim)
    if ($confirm | is-empty) { $confirm = "y" }
    if $confirm != "y" {
        print "Aborted."
        return
    }

    let tmp_body = $"/tmp/pr-body-(date now | format date '%Y%m%d%H%M%S').md"
    $body | save --force $tmp_body
    eml $tmp_body
    let body = (open --raw $tmp_body)

    ^jj git push --remote $remote --named $"($bookmark)=@-"
    let pr_url = (
        {
            title: $title,
            head:  $bookmark,
            base:  $base,
            body:  $body,
            draft: $draft,
        }
        | to json
        | ^gh api $"repos/($repo)/pulls" --method POST --input -
        | from json
        | get html_url
    )
    print $"PR created: ($pr_url)"
}
