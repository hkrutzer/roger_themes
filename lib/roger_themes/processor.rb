require "roger/release"
require "roger/release/processors/mockup"

module RogerThemes
  class Processor < Roger::Release::Processors::Base
    self.name = :roger_themes

    def default_options
      {
        default_theme: 'default',
        excludes: [
          /\A_doc\/.*/,
          /\Athemes\/.*/,
          "index.html"
        ],
        shared_folders: ["images", "fonts"],
        template_glob: "**/*{.html,.html.erb}"
      }
    end

    def copy_templates_to_theme(template_files, template_root, theme_path)
      puts "--> #{template_root} - #{theme_path}"
      mkdir_p theme_path

      template_files.each do |file|
        mkdir_p theme_path + File.dirname(file)
        cp template_root + file, theme_path + file
      end
    end

    def copy_shared_to_theme(theme, theme_path)
      release.debug self, "Copying shared assets from #{options[:shared_folders]} for #{theme.name}"
      shared_folders = SharedFolders.new(options[:shared_folders])

      shared_folders.folders.each do |source, target|
        if File.directory? release.build_path + source.to_s
          cp_r release.build_path + "#{source}/.", theme_path + target
        end
      end
    end

    def mockup(path, env = {})
      processor = Roger::Release::Processors::Mockup.new

      release.log self, "Running mockup processor for: #{path}"
      processor.call(release, {
        match: [
          path + options[:template_glob]
        ],
        env: {
          "roger.project" => release.project
        }.update(env)
      })
    end

    def perform
      themes_path = release.build_path + RogerThemes.themes_path
      main_themes = Theme.main_themes(themes_path)

      # Get templates from html path
      template_files = Dir.glob(release.project.html_path + options[:template_glob]).map{ |f| f.sub(release.project.html_path.to_s + "/", "") }
      template_files.reject!{|c| options[:excludes].detect{|e| e.match(c) } }

      release.debug self, "Copying theme files #{template_files.inspect}"

      main_themes.each do |main_theme|
        copy_templates_to_theme(template_files, release.project.html_path, main_theme.html_path)
        mockup(main_theme.html_path, { "MAIN_THEME" => main_theme })
        copy_shared_to_theme(main_theme, main_theme.path)

        # Copy sub theme to MAINTHEME.SUBTHEME
        main_theme.sub_themes.each do |sub_theme|
          sub_theme_html_path = sub_theme.html_path_in_main(main_theme.name)

          # Copy template files to main
          copy_templates_to_theme(template_files, release.project.html_path, sub_theme_html_path)

          # Run mockup
          mockup(sub_theme_html_path, { "MAIN_THEME" => main_theme, "SUB_THEME" => sub_theme })
        end
      end

      # Make sure we got all shared files in our sub themes
      Theme.sub_themes(themes_path).each do |sub_theme|
        copy_shared_to_theme(sub_theme, sub_theme.path)
      end
    end
  end
end
