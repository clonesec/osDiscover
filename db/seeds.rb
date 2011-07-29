# coding: utf-8

# See https://github.com/rails/rails/blob/59f7780a3454a14054d1d33d9b6e31192ab2e58b/activemodel/lib/active_model/mass_assignment_security/sanitizer.rb
# Allow mass assignment in seeds.rb
module ActiveModel
  module MassAssignmentSecurity
    module Sanitizer
      def sanitize(attributes)
        attributes
      end
    end
  end
end

User.delete_all
