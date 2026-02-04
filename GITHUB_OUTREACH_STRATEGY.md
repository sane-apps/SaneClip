# GitHub Outreach Strategy - SaneApps

**Mission:** Convert the 752 cloners into stars and customers.

## The Problem

- **752 total clones** (190 unique) across SaneApps repos
- **Only 7 stars** on SaneClip (0.9% conversion)
- **1 sale** (0.13% conversion)
- GitHub API doesn't expose WHO cloned (privacy protected)

## What We CAN Track

GitHub gives us:
1. **Stargazers** - who starred (public)
2. **Forkers** - who forked (public)
3. **Watchers** - who's watching (public)
4. **Issue/PR authors** - who engaged (public)
5. **Commenters** - who commented on issues/PRs (public)

## Target Audiences

### 1. Forkers Who Didn't Star
**Why target:** They found it valuable enough to fork but forgot to star
**Approach:** Comment on their most recent repo
**Message template:**
```
Hey! Noticed you forked SaneBar/SaneClip/SaneHosts - how's it working for you?

If it's helping you out, drop a star on the repo! ⭐
Helps others discover it.

Let me know if you hit any issues - I built this and I'm here to help.
```

### 2. Issue/PR Authors Who Didn't Star
**Why target:** They engaged deeply enough to report bugs or contribute
**Approach:** Reply in their issue/PR thread
**Message template:**
```
Thanks for the feedback/contribution! Really appreciate you taking the time.

If SaneBar/SaneClip is useful to you, consider starring the repo ⭐
Stars help us prioritize which projects get the most attention.
```

### 3. Watchers Who Didn't Star
**Why target:** They're interested enough to watch but haven't starred
**Approach:** Comment on their most recent repo
**Message template:**
```
Saw you're watching SaneBar/SaneClip!

If you find it useful, star the repo ⭐ - takes 1 second and helps others find quality open source.

Also happy to answer any questions about the project!
```

### 4. Competitors' GitHub Issues
**Why target:** People actively complaining about competitors are prime prospects
**Approach:** Comment with genuine help (ALWAYS disclose you're the dev)
**Message template:**
```
I built SaneBar (competitor to [X]). I saw your issue about [specific problem].

SaneBar handles this by [solution]. It's $5 one-time or free if you build from source.

Disclaimer: I'm the dev, so obviously biased, but happy to answer questions!

Repo: https://github.com/sane-apps/SaneBar
```

## Execution Steps

### Step 1: Pull All Engagement Data
```bash
# For each repo (SaneClip, SaneBar, SaneHosts, SaneClick):

# Get stargazers
gh api repos/sane-apps/REPO/stargazers --paginate --jq '.[].login' > stargazers.txt

# Get forkers
gh api repos/sane-apps/REPO/forks --paginate --jq '.[].owner.login' > forkers.txt

# Get watchers
gh api repos/sane-apps/REPO/subscribers --paginate --jq '.[].login' > watchers.txt

# Get issue authors
gh api repos/sane-apps/REPO/issues --paginate --jq '.[].user.login' > issue_authors.txt

# Find people who engaged but didn't star
comm -23 <(sort forkers.txt) <(sort stargazers.txt) > no_star_forks.txt
comm -23 <(sort watchers.txt) <(sort stargazers.txt) > no_star_watchers.txt
comm -23 <(sort issue_authors.txt) <(sort stargazers.txt) > no_star_issues.txt
```

### Step 2: Get Their Repos
```bash
# For each user in no_star_*.txt:
for user in $(cat no_star_forks.txt); do
  # Get their most recent public repo
  gh api users/$user/repos --jq 'sort_by(.pushed_at) | reverse | .[0] | {name, full_name, description}'
done
```

### Step 3: Draft Personalized Comments
For each target:
1. Visit their most recent repo
2. Look at what they're building
3. Personalize the message: "Noticed you forked SaneBar and I see you're working on [their project] - that's awesome!"
4. Add star request
5. Offer help

### Step 4: Post Comments (Manual Review First!)
**CRITICAL:** Review every comment before posting. Make sure:
- It's genuinely helpful, not spammy
- You identify yourself as the dev ("I built SaneBar")
- It's relevant to their repo
- Tone is friendly, not demanding

## Competitor Monitoring

### Target Repos
- **Bartender** - https://github.com/stnolting/Bartender (fan port, not official)
- **Hidden Bar** - https://github.com/dwarvesf/hidden (abandoned)
- **Ice** - https://github.com/jordanbaird/Ice (broken, active issues)
- **Maccy** - https://github.com/p0deje/Maccy (clipboard manager, no security)

### What to Watch
1. **Open issues** about missing features we have
2. **Feature requests** we already support
3. **Bug reports** we don't have
4. **"Looking for alternatives"** comments

### Engagement Rules
1. **ALWAYS identify as the dev** - "I built SaneBar..."
2. **Be genuinely helpful** - don't just sell
3. **Acknowledge their choice** - "If you're happy with [X], stick with it. But if you hit issues, SaneBar might help."
4. **No trash talk** - respect competitors

## Reddit/HN Monitoring

Use `/outreach` skill to scan:
- r/macapps
- r/MacOS
- r/privacy
- HackerNews "Show HN" and "Ask HN"

Look for:
- "Looking for clipboard manager"
- "Alternatives to Bartender"
- "Privacy-focused Mac apps"

## Success Metrics

Track weekly:
- Stars gained
- Comments posted
- Replies received
- Sales from GitHub traffic (Lemon Squeezy referrer tracking)

## Anti-Spam Guardrails

**NEVER:**
- Mass-comment without personalization
- Comment on unrelated repos
- Hide that you're the dev
- Be pushy or demanding
- Comment more than once on same person's repos

**ALWAYS:**
- Disclose you built it
- Make it about helping them
- Respect "no thanks" responses
- Be genuinely useful first

## Tools

1. **`gh` CLI** - GitHub API access
2. **`/outreach` skill** - Automated Reddit/HN/GitHub scanning
3. **`/social` skill** - Draft tweets about updates
4. **Lemon Squeezy referrer tracking** - See which outreach works

## Next Session

1. Run the data pull scripts
2. Generate target list with repos
3. Draft 10 personalized comments
4. Review and post (manually)
5. Track responses
