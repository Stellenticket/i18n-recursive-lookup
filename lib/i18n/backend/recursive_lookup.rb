require 'active_support'
require 'active_support/core_ext'

module I18n
  module Backend
    module RecursiveLookup
      REPLACEMENT_PATTERN =
        /\A\$\{([\w\.]+)\}\Z/ # "${foo.bla}" (nothing more on line)
      INTERPOLATION_PATTERN =
        /(\$?\$)\{([\w\.]+)\}/ # "abc ${foo.bla} cde" and "abc $${some.thing} cde"

      def lookup(*args)
        result = super

        result && transform(result) || cut_key_and_try_again(*args)
      end

      def transform(entry)
        if entry.is_a?(String)
          replace_reference(entry)
        elsif entry.is_a?(Hash)
          entry.transform_values! { |e| transform(e) }
        else
          entry
        end
      end

      def replace_reference(entry)
        if entry =~ REPLACEMENT_PATTERN
          I18n.t(Regexp.last_match(1))
        else
          entry.gsub(INTERPOLATION_PATTERN) do
            key = Regexp.last_match(2)
            if Regexp.last_match(1) == '$$'
              "${#{key}}"
            else
              I18n.t(key)
            end
          end
        end
      end

      def cut_key_and_try_again(locale, key, scope, *args)
        normalized_key = I18n.normalize_keys(nil, key, scope)
        return if normalized_key.size < 2

        # simply strip the last key part, e.g. `foo.bar.baz` becomes `foo.bar`
        popped = normalized_key.pop

        # look it up
        up = lookup(locale, normalized_key, scope, *args)

        # if something is found, return the popped key we originally wanted
        up && up[popped]
      end
    end
  end
end
