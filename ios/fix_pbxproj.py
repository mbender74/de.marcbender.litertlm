import re, os, random

pbxproj_path = 'TitaniumLiteRTLM.xcodeproj/project.pbxproj'

def new_uuid():
    return ''.join(random.choices('0123456789ABCDEF', k=24))

def find_section_end(content, section_name):
    """Find the actual 'End' marker for a section on its own line."""
    end_marker = '/* End ' + section_name + ' section */'
    start_marker = '/* Begin ' + section_name + ' section */'
    start_pos = content.find(start_marker)
    if start_pos == -1:
        return -1
    search_from = start_pos + len(start_marker)
    while True:
        pos = content.find(end_marker, search_from)
        if pos == -1:
            return -1
        # Verify the end marker is on its own line
        before_char = content[pos - 1] if pos > 0 else ''
        after_char = content[pos + len(end_marker)] if pos + len(end_marker) < len(content) else ''
        if (before_char == '\n' or before_char == ' ') and (after_char == '\n' or after_char == ' '):
            return pos
        search_from = pos + 1

with open(pbxproj_path, 'r') as f:
    content = f.read()

# Collect Swift files
all_swift_files = []
for root, dirs, files in os.walk('Classes'):
    for f in files:
        if f.endswith('.swift'):
            all_swift_files.append(os.path.join(root, f))

xcframework_path = 'platform/LiteRTLM.xcframework'

file_uuids = {}
build_uuids = {}
for fp in all_swift_files:
    rel = os.path.relpath(fp, '.')
    bn = os.path.basename(fp)
    file_uuids[rel] = new_uuid()
    build_uuids[rel] = new_uuid()

xfw_ref_uuid = new_uuid()
xfw_build_uuid = new_uuid()

# Step 1: PBXFileReference
file_ref_end = find_section_end(content, 'PBXFileReference')
if file_ref_end == -1:
    print('Could not find PBXFileReference end')
    exit(1)

new_file_refs = ''
for fp in all_swift_files:
    rel = os.path.relpath(fp, '.')
    bn = os.path.basename(fp)
    dir_path = os.path.dirname(rel)
    uuid = file_uuids[rel]
    if dir_path:
        display = '/* ' + dir_path + '/' + bn + ' */'
        nf = 'name = ' + bn + '; path = ' + dir_path + '/' + bn + ';'
    else:
        display = '/* ' + bn + ' */'
        nf = 'name = ' + bn + '; path = ' + bn + ';'
    entry = '    ' + uuid + ' ' + display + ' = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; ' + nf + ' sourceTree = "<group>"; };\n'
    new_file_refs += entry

xfw_entry = '    ' + xfw_ref_uuid + ' /* LiteRTLM.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = LiteRTLM.xcframework; path = ' + xcframework_path + '; sourceTree = "<group>"; };\n'
new_file_refs += xfw_entry
content = content[:file_ref_end] + new_file_refs + content[file_ref_end:]

# Step 2: PBXBuildFile
build_file_end = find_section_end(content, 'PBXBuildFile')
if build_file_end == -1:
    print('Could not find PBXBuildFile end')
    exit(1)

new_build_files = ''
for fp in all_swift_files:
    rel = os.path.relpath(fp, '.')
    bn = os.path.basename(fp)
    dir_path = os.path.dirname(rel)
    bu = build_uuids[rel]
    fu = file_uuids[rel]
    if dir_path:
        display = '/* ' + dir_path + '/' + bn + ' in Sources */'
    else:
        display = '/* ' + bn + ' in Sources */'
    entry = '    ' + bu + ' ' + display + ' = {isa = PBXBuildFile; fileRef = ' + fu + ' /* ' + bn + ' */; };\n'
    new_build_files += entry

xfw_build_entry = '    ' + xfw_build_uuid + ' /* LiteRTLM.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = ' + xfw_ref_uuid + ' /* LiteRTLM.xcframework */; };\n'
new_build_files += xfw_build_entry
content = content[:build_file_end] + new_build_files + content[build_file_end:]

# Step 3: FrameworksBuildPhase
fw_end = find_section_end(content, 'PBXFrameworksBuildPhase')
if fw_end == -1:
    print('Could not find PBXFrameworksBuildPhase end')
    exit(1)
fw_section = content[content.find('/* Begin PBXFrameworksBuildPhase section */'):fw_end]
last_file_pattern = r'([0-9A-F]{24}) /\* TitaniumKit\.xcframework in Frameworks \*/'
last_file_match = re.search(last_file_pattern, fw_section)
if last_file_match:
    abs_pos = content.find(last_file_match.group(0)) + len(last_file_match.group(0))
    after = content[abs_pos:fw_end]
    close_paren = after.find(');')
    if close_paren != -1:
        insert_at = abs_pos + close_paren
        content = content[:insert_at] + ',\n        ' + xfw_build_uuid + ' /* LiteRTLM.xcframework in Frameworks */' + content[insert_at:]

# Step 4: SourcesBuildPhase
ss = find_section_end(content, 'PBXSourcesBuildPhase')
ss_start = content.find('/* Begin PBXSourcesBuildPhase section */')
if ss != -1 and ss_start != -1:
    inner = content[ss_start:ss]
    ffm = re.search(r'files = \(', inner)
    lfm = re.search(r'\);', inner)
    if ffm and lfm:
        rs = ss_start + ffm.end()
        re2 = ss_start + lfm.start()
        nfl = 'files = (\n'
        for fp in all_swift_files:
            rel = os.path.relpath(fp, '.')
            bn = os.path.basename(fp)
            dp = os.path.dirname(rel)
            u = build_uuids[rel]
            if dp:
                d = u + ' /* ' + dp + '/' + bn + ' in Sources */'
            else:
                d = u + ' /* ' + bn + ' in Sources */'
            nfl += '        ' + d + ',\n'
        nfl += '    );\n'
        content = content[:rs-1] + nfl + content[re2:]

# Step 5: PBXGroup
gs = content.find('/* Begin PBXGroup section */')
ge = find_section_end(content, 'PBXGroup')
if gs != -1 and ge != -1:
    chunk = content[gs:ge]
    matches = list(re.finditer(r'(DB[0-9A-F]{24}) /\* Frameworks \*/ = \{\s+isa = PBXGroup;\s+children = \(([^)]*)\)\s+name = Frameworks;', chunk, re.DOTALL))
    tu = None
    for m in matches:
        st = gs + m.start()
        c = content[st:st+1000]
        if 'TitaniumKit.xcframework' in c:
            tu = m.group(1)
            break
    if tu:
        pat = '(' + tu + r' /\* Frameworks \*/ = \{\s+isa = PBXGroup;\s+children = \()(.*?)(\)\s+name = Frameworks;)'
        match = re.search(pat, content, re.DOTALL)
        if match:
            oc = match.group(2).strip()
            if 'LiteRTLM.xcframework' not in oc:
                nc = oc + ',\n        ' + xfw_ref_uuid + ' /* LiteRTLM.xcframework */'
                content = content[:match.start(3)] + nc + content[match.end(2):]

with open(pbxproj_path, 'w') as f:
    f.write(content)

print('Done: ' + str(len(all_swift_files)) + ' Swift files + XCFramework added')
