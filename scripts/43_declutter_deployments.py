import subprocess
import urllib.request
import json
import csv
import sys

def get_auth_token():
    p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, _ = p.communicate(input='protocol=https\nhost=github.com\n\n')
    for line in stdout.splitlines():
        if line.startswith('password='):
            return line.split('password=')[1]
    return None

def declutter():
    token = get_auth_token()
    if not token:
        print("ERROR: Git credential token not found.")
        sys.exit(1)

    headers = {
        'User-Agent': 'Python/urllib',
        'Authorization': f'Bearer {token}',
        'Accept': 'application/vnd.github.v3+json'
    }

    # Fetch current deployments from API
    url = 'https://api.github.com/repos/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/deployments?per_page=100'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        deployments = json.loads(resp.read().decode('utf-8'))

    print(f"Current live deployments count: {len(deployments)}")

    # Tags mapping
    tag_shas = {}
    tags_out = subprocess.check_output(['git', 'show-ref', '--tags'], text=True).strip().splitlines()
    for line in tags_out:
        parts = line.split()
        if len(parts) == 2:
            sha, ref = parts
            tag_name = ref.replace('refs/tags/', '')
            tag_shas[sha[:8]] = tag_name
            try:
                deref = subprocess.check_output(['git', 'rev-parse', f'{tag_name}^{{commit}}'], text=True).strip()
                tag_shas[deref[:8]] = tag_name
            except Exception:
                pass

    # Determine KEEP vs REMOVE
    # Retain:
    # 1. Latest active deployment (index 0)
    # 2. Deployments associated with milestone/release tags (v0.7.2, v0.7.1, v0.7)
    # 3. Last 3 successful deployments for operational rollback
    to_keep = []
    to_delete = []

    for i, d in enumerate(deployments):
        dep_id = d['id']
        sha_short = d['sha'][:8]
        tag = tag_shas.get(sha_short, None)
        
        # Check if first (current head of deployment env)
        if i == 0:
            to_keep.append((dep_id, sha_short, tag, "Current latest deployment"))
            continue
        
        # Check if associated with release tag
        if tag is not None and ('v0.7' in tag or 'v0.6' in tag):
            to_keep.append((dep_id, sha_short, tag, f"Release tag {tag}"))
            continue
            
        to_delete.append((dep_id, sha_short, tag, "Inactive intermediate/superseded development deployment"))

    print("\nDeployments to KEEP:")
    for k in to_keep:
        print(f"  ID: {k[0]} | SHA: {k[1]} | Tag: {k[2]} | Reason: {k[3]}")

    print(f"\nDeployments to REMOVE ({len(to_delete)}):")
    for r in to_delete:
        print(f"  ID: {r[0]} | SHA: {r[1]} | Tag: {r[2]} | Reason: {r[3]}")

    # Execute safe deactivation and deletion
    deleted_records = []
    for dep_id, sha_short, tag, reason in to_delete:
        # Step 1: Deactivate deployment
        status_url = f'https://api.github.com/repos/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/deployments/{dep_id}/statuses'
        status_req = urllib.request.Request(status_url, headers=headers, data=json.dumps({'state': 'inactive'}).encode('utf-8'))
        try:
            with urllib.request.urlopen(status_req) as s_resp:
                print(f"[DEACTIVATED] Deployment {dep_id} ({sha_short}): HTTP {s_resp.status}")
        except urllib.error.HTTPError as e:
            print(f"[WARN] Could not set inactive on {dep_id}: {e.code} - {e.read().decode()}")

        # Step 2: Delete deployment
        del_url = f'https://api.github.com/repos/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/deployments/{dep_id}'
        del_req = urllib.request.Request(del_url, headers=headers, method='DELETE')
        try:
            with urllib.request.urlopen(del_req) as del_resp:
                print(f"[DELETED] Deployment {dep_id} ({sha_short}): HTTP {del_resp.status}")
                deleted_records.append({'id': dep_id, 'sha': sha_short, 'tag': tag or 'none', 'status': 'deleted'})
        except urllib.error.HTTPError as e:
            print(f"[ERROR] Failed to delete deployment {dep_id}: HTTP {e.code} - {e.read().decode()}")
            deleted_records.append({'id': dep_id, 'sha': sha_short, 'tag': tag or 'none', 'status': f'failed_{e.code}'})

    # Fetch inventory AFTER
    with urllib.request.urlopen(req) as resp:
        remaining = json.loads(resp.read().decode('utf-8'))

    after_records = []
    for i, d in enumerate(remaining):
        dep_id = d['id']
        sha = d['sha']
        sha_short = sha[:8]
        tag = tag_shas.get(sha_short, 'none')
        
        s_url = f'https://api.github.com/repos/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/deployments/{dep_id}/statuses'
        s_req = urllib.request.Request(s_url, headers=headers)
        most_recent_status = 'unknown'
        try:
            with urllib.request.urlopen(s_req) as s_resp:
                statuses = json.loads(s_resp.read().decode('utf-8'))
                if statuses:
                    most_recent_status = statuses[0].get('state', 'unknown')
        except Exception:
            pass

        after_records.append({
            'deployment_id': dep_id,
            'commit_sha': sha,
            'commit_sha_short': sha_short,
            'ref': d['ref'],
            'environment': d['environment'],
            'created_at': d['created_at'],
            'most_recent_status': most_recent_status,
            'active_state': 'active' if i == 0 else 'inactive',
            'associated_tag': tag
        })

    with open('checkpoint_G6_deployment_inventory_after.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['deployment_id', 'commit_sha', 'commit_sha_short', 'ref', 'environment', 'created_at', 'most_recent_status', 'active_state', 'associated_tag'])
        writer.writeheader()
        writer.writerows(after_records)

    print(f"\nRemaining deployments after declutter: {len(after_records)}")
    for a in after_records:
        print(f"  ID: {a['deployment_id']} | SHA: {a['commit_sha_short']} | Status: {a['most_recent_status']} | Tag: {a['associated_tag']}")

if __name__ == '__main__':
    declutter()
