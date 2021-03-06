module Alchemy
  class PageTreeSerializer < BaseSerializer
    def attributes
      {'pages' => nil}
    end

    def pages
      tree = []
      path = [{id: object.parent_id, children: tree}]
      page_list = object.self_and_descendants
      skip_branch = false
      base_level = object.level - 1

      page_list.each_with_index do |page, i|
        has_children = page_list[i + 1] && page_list[i + 1].parent_id == page.id
        folded = has_children && page.folded?(opts[:user])

        if skip_branch
          next if page.parent_id == path.last[:children].last[:id]

          skip_branch = false
        end

        # Do not walk my children if I'm folded and you don't need to have the
        # full tree.
        if folded && !opts[:full]
          skip_branch = true
        end

        if page.parent_id != path.last[:id]
          if path.map { |o| o[:id] }.include?(page.parent_id) # Lower level
            path.pop while path.last[:id] != page.parent_id
          else # One level up
            path << path.last[:children].last
          end
        end

        level = path.count + base_level

        path.last[:children] << page_hash(page, has_children, level, folded)
      end

      tree
    end

    protected

    def page_hash(page, has_children, level, folded)
      {
        id: page.id,
        name: page.name,
        permissions: page_permissions(page, opts[:ability]),
        public: page.public?,
        visible: page.visible?,
        restricted: page.restricted?,
        status_titles: page_status_titles(page),
        page_layout: page.page_layout,
        slug: page.slug,
        redirects_to_external: page.redirects_to_external?,
        locked: page.locked,
        definition_missing: page.definition.blank?,
        urlname: page.urlname,
        external_urlname: page.external_urlname,
        level: level,
        root: level == 1,
        folded: folded,
        root_or_leaf: level == 1 || !has_children,
        children: []
      }
    end

    def page_permissions(page, ability)
      {
        info: ability.can?(:info, page),
        configure: ability.can?(:configure, page),
        copy: ability.can?(:copy, page),
        destroy: ability.can?(:destroy, page),
        create: ability.can?(:create, Alchemy::Page)
      }
    end

    def page_status_titles(page)
      {
        public: page.status_title(:public),
        visible: page.status_title(:visible),
        restricted: page.status_title(:restricted)
      }
    end
  end
end
