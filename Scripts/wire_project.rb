#!/usr/bin/env ruby
# Wires the EverywhereCore SwiftPM package + zashboard resource bundle
# into Everywhere.xcodeproj (macOS). Idempotent — running it twice is safe.
#
# EverywhereCore ships as a prebuilt xcframework on GitHub Releases; SwiftPM
# downloads and verifies it. The app target embeds it; the network extension
# target links against it and loads at runtime from the app bundle.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Everywhere.xcodeproj', __dir__)
DASHBOARD_REL_PATH = 'ThirdParty/zashboard'
DASHBOARD_NAME = 'zashboard'
DEPLOYMENT_TARGET = '14.0'
SHARED_FOLDER = 'Shared'

EVERYWHERE_CORE_REPO    = 'https://github.com/NodePassProject/EverywhereCore'
EVERYWHERE_CORE_VERSION = '2026.05.18'
EVERYWHERE_CORE_PRODUCT = 'EverywhereCore'

project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == 'Everywhere' } or abort 'Everywhere target missing'
ne_target  = project.targets.find { |t| t.name == 'EverywhereNE' } or abort 'EverywhereNE target missing'

# --- Tear down any prior local-xcframework wiring -------------------------
# Self-healing for repos previously wired against Frameworks/EverywhereCore.xcframework.
stale_xcfw = project.files.select { |f| f.path == 'Frameworks/EverywhereCore.xcframework' }
stale_xcfw.each do |ref|
  project.targets.each do |t|
    t.frameworks_build_phase.files.select { |bf| bf.file_ref == ref }.each do |bf|
      t.frameworks_build_phase.files.delete(bf)
    end
    t.copy_files_build_phases.each do |cp|
      cp.files.select { |bf| bf.file_ref == ref }.each do |bf|
        cp.files.delete(bf)
      end
    end
  end
  ref.remove_from_project
end

# Strip $(PROJECT_DIR)/Frameworks from FRAMEWORK_SEARCH_PATHS now that
# SwiftPM owns the binary — leaving it is harmless but noisy.
stale_search_path = '$(PROJECT_DIR)/Frameworks'
[app_target, ne_target].each do |target|
  target.build_configurations.each do |config|
    paths = config.build_settings['FRAMEWORK_SEARCH_PATHS']
    next unless paths.is_a?(Array) && paths.include?(stale_search_path)
    paths.delete(stale_search_path)
    if paths == ['$(inherited)'] || paths.empty?
      config.build_settings.delete('FRAMEWORK_SEARCH_PATHS')
    else
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] = paths
    end
  end
end

# --- Remote SwiftPM package reference ------------------------------------
pkg_ref = project.root_object.package_references.find do |pr|
  pr.respond_to?(:repositoryURL) && pr.repositoryURL == EVERYWHERE_CORE_REPO
end
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = EVERYWHERE_CORE_REPO
  project.root_object.package_references << pkg_ref
end
pkg_ref.requirement = { 'kind' => 'exactVersion', 'version' => EVERYWHERE_CORE_VERSION }

# --- Per-target product dependency + link --------------------------------
def add_product_dep(target, project, package_ref, product_name)
  dep = target.package_product_dependencies.find do |d|
    d.product_name == product_name && d.package == package_ref
  end
  unless dep
    dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dep.package = package_ref
    dep.product_name = product_name
    target.package_product_dependencies << dep
  end
  dep
end

def link_product(target, project, dep)
  phase = target.frameworks_build_phase
  return if phase.files.any? { |bf| bf.product_ref == dep }
  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  phase.files << bf
end

app_dep = add_product_dep(app_target, project, pkg_ref, EVERYWHERE_CORE_PRODUCT)
ne_dep  = add_product_dep(ne_target,  project, pkg_ref, EVERYWHERE_CORE_PRODUCT)
link_product(app_target, project, app_dep)
link_product(ne_target,  project, ne_dep)

# No manual Embed Frameworks entry: Xcode auto-embeds the framework slice
# from a SwiftPM binary target into the app bundle when the product is in
# the Frameworks build phase. Adding it to a Copy Files phase by productRef
# double-resolves and fails with "No such file or directory" on the bare
# product name. The network extension links the same product but is not
# embedded — it loads from the host app's Frameworks/ at runtime.
stale_embed = app_target.copy_files_build_phases.find do |p|
  p.symbol_dst_subfolder_spec == :frameworks
end
if stale_embed
  stale_embed.files.select { |bf|
    bf.product_ref&.product_name == EVERYWHERE_CORE_PRODUCT
  }.each { |bf| stale_embed.files.delete(bf) }
  if stale_embed.files.empty?
    app_target.build_phases.delete(stale_embed)
    stale_embed.remove_from_project
  end
end

# --- libresolv.tbd (Go runtime's DNS resolver needs it) ------------------
def link_system_lib(target, project, name, sdk_path)
  return if target.frameworks_build_phase.files.any? do |bf|
    bf.file_ref&.path == sdk_path
  end
  ref = project.frameworks_group.files.find { |f| f.path == sdk_path }
  unless ref
    ref = project.frameworks_group.new_file(sdk_path)
    ref.source_tree = 'SDKROOT'
    ref.name = name
    ref.last_known_file_type = 'sourcecode.text-based-dylib-definition'
  end
  target.frameworks_build_phase.add_file_reference(ref)
end

link_system_lib(ne_target,  project, 'libresolv.tbd', 'usr/lib/libresolv.tbd')
link_system_lib(app_target, project, 'libresolv.tbd', 'usr/lib/libresolv.tbd')

# --- MACOSX_DEPLOYMENT_TARGET (project + every target) -------------------
project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
end
[app_target, ne_target].each do |target|
  target.build_configurations.each do |config|
    if config.build_settings.key?('MACOSX_DEPLOYMENT_TARGET')
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    end
  end
end

# --- zashboard folder reference (bundled into the app target) -----------
# `lastKnownFileType = folder` is the magic that makes Xcode treat this
# as a "blue folder" — it copies the whole tree into the .app preserving
# relative paths, which the dashboard's index.html requires
# (./assets/index-*.js). Self-healing cleanup catches the legacy
# yacd-gh-pages reference and any moved zashboard ref.
project.files.select { |f|
  next false unless f.path
  basename = File.basename(f.path)
  (basename == 'yacd-gh-pages' || basename == DASHBOARD_NAME) &&
    f.path != DASHBOARD_REL_PATH
}.each do |stale|
  project.targets.each do |t|
    t.resources_build_phase.files.select { |bf| bf.file_ref == stale }.each do |bf|
      t.resources_build_phase.files.delete(bf)
    end
  end
  stale.remove_from_project
end

dashboard_ref = project.main_group.files.find { |f| f.path == DASHBOARD_REL_PATH }
unless dashboard_ref
  dashboard_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  dashboard_ref.path = DASHBOARD_REL_PATH
  dashboard_ref.name = DASHBOARD_NAME
  dashboard_ref.source_tree = 'SOURCE_ROOT'
  dashboard_ref.last_known_file_type = 'folder'
  project.main_group << dashboard_ref
end
unless app_target.resources_build_phase.files.any? { |bf| bf.file_ref == dashboard_ref }
  app_target.resources_build_phase.add_file_reference(dashboard_ref)
end

# --- Shared/ synced root group (both targets compile its sources) --------
# Sources that both the host app and the Network Extension need —
# Core Data stack, EVCore helper, ConfigNormalizer, etc. — live in
# Shared/. The folder is registered as a PBXFileSystemSynchronizedRootGroup
# on both targets so every .swift inside auto-joins each target's
# Sources build phase. This is the canonical Xcode-16 way to share
# sources across targets without per-file membership exceptions.
shared_group = project.main_group.children.find do |c|
  c.is_a?(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup) && c.path == SHARED_FOLDER
end
unless shared_group
  shared_group = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
  shared_group.path = SHARED_FOLDER
  shared_group.source_tree = '<group>'
  project.main_group << shared_group
end
[app_target, ne_target].each do |target|
  target.file_system_synchronized_groups ||= []
  next if target.file_system_synchronized_groups.include?(shared_group)
  target.file_system_synchronized_groups << shared_group
end

project.save
puts "Wired EverywhereCore @ #{EVERYWHERE_CORE_VERSION} (SwiftPM) + zashboard + Shared/ into #{PROJECT_PATH}"
