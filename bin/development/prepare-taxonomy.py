#!/usr/bin/env python3
"""Validate the pinned snapshot and prepare PostgreSQL COPY text, preserving values."""
import csv, gzip, hashlib, json, pathlib, collections
root = pathlib.Path(__file__).resolve().parents[2]
p = root / 'resources/inaturalist/2026-10-14'
out = p / 'initialization'
out.mkdir(exist_ok=True)
manifest = json.loads((p / 'manifest.json').read_text())
for f in manifest['files']:
    assert hashlib.sha256((p / f['file']).read_bytes()).hexdigest() == f['sha256'], f['file']
iconic = {r['id'] for r in json.loads((p/'iconic-taxa.json').read_text())['results']}
rows = {}
with gzip.open(p/'taxa.csv.gz', 'rt') as stream:
    for r in csv.DictReader(stream, delimiter='\t', quoting=csv.QUOTE_NONE):
        ident = int(r['taxon_id'])
        assert ident > 0 and ident not in rows
        assert r['active'] in ('true', 'false')
        assert r['name'] and r['rank'] and max(len(r[k]) for k in ('name','rank','ancestry')) <= 255
        rows[ident] = (r['ancestry'], float(r['rank_level']) if r['rank_level'] else None, r['rank'], r['name'], r['active'])
assert iconic <= rows.keys()
issues = collections.Counter(); examples = {}
with (out/'taxa-copy.tsv').open('w') as dest:
    for ident,(ancestry,level,rank,name,active) in rows.items():
        chain = [int(x) for x in ancestry.split('/') if x]
        assert ident not in chain and len(chain)==len(set(chain)), ident
        assert all(x in rows for x in chain), ident
        if chain:
            parent=rows[chain[-1]]
            checks={'parent_ancestry_mismatch':parent[0] != '/'.join(map(str,chain[:-1])),
                    'parent_rank_not_coarser':parent[1] is not None and level is not None and parent[1] <= level,
                    'active_child_inactive_parent':active=='true' and parent[4]!='true'}
            for key,bad in checks.items():
                if bad:
                    issues[key]+=1
                    examples.setdefault(key,[])
                    if len(examples[key])<10: examples[key].append(ident)
        icon=next((x for x in reversed(chain+[ident]) if x in iconic),None)
        fields=[ident,ancestry or None,level,rank,name,active,str(ident in iconic).lower(),icon]
        dest.write('\t'.join('\\N' if x is None else str(x).replace('\\','\\\\').replace('\t','\\t').replace('\n','\\n').replace('\r','\\r') for x in fields)+'\n')
parents = {i: int(r[0].split('/')[-1]) if r[0] else None for i,r in rows.items()}
visited = set()
for ident in parents:
    chain = set(); node = ident
    while node is not None and node not in visited:
        assert node not in chain, ('parent cycle', node)
        chain.add(node); node = parents[node]
    visited.update(chain)
missing = [i for i,r in rows.items() if r[1] is None]
report={'rows':len(rows),'iconic_ids':sorted(iconic),'ancestry_issues':dict(issues),'issue_examples':examples,
        'parent_cycles':0,'missing_rank_level_count':len(missing),'missing_rank_level_ids':missing}
(out/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
# Source anomalies are reported, never silently repaired in this replica.
