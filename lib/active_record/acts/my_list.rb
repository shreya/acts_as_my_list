module ActiveRecord
  module Acts 
    module MyList 
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_my_list(options = {})

          class_eval <<-EOV
            include ActiveRecord::Acts::MyList::InstanceMethods

            def acts_as_list_class
              ::#{self.name}
            end

            before_destroy :decrement_positions_on_lower_items
            before_create  :add_to_list_bottom
          EOV
        end
      end

      module InstanceMethods

        # Swap positions with the next lower item, if one exists.
        def move_lower
          return unless lower_item

          acts_as_list_class.transaction do
            lower_item.decrement_position
            increment_position
          end
        end


        def higher_item
          return nil unless in_list?
          acts_as_list_class.find(:first, :conditions =>
            "position = #{(send(:position).to_i - 1).to_s}"
          )
        end

        # Return the next lower item in the list.
        def lower_item
          return nil unless in_list?
          acts_as_list_class.find(:first, :conditions =>
            "position = #{(send(:position).to_i + 1).to_s}"
          )
        end

        # Swap positions with the next higher item, if one exists.
        def move_higher
          return unless higher_item

          acts_as_list_class.transaction do
            higher_item.increment_position
            decrement_position
          end
        end

        # Move to the bottom of the list. If the item is already in the list, the items below it have their
        # position adjusted accordingly.
        def move_to_bottom
          return unless in_list?
          acts_as_list_class.transaction do
            decrement_positions_on_lower_items
            assume_bottom_position
          end
        end

        # Move to the top of the list. If the item is already in the list, the items above it have their
        # position adjusted accordingly.
        def move_to_top
          return unless in_list?
          acts_as_list_class.transaction do
            increment_positions_on_higher_items
            assume_top_position
          end
        end

         # Test if this record is in a list
        def in_list?
          !send(:position).nil?
        end
        
        
        def increment_position
          return unless in_list? #and self.send(:position) != 1
          update_attribute :position, self.send(:position).to_i + 1
        end

        # Decrease the position of this item without adjusting the rest of the list.
        def decrement_position
          return unless in_list?
          update_attribute :position, self.send(:position).to_i - 1
        end

        private

          def add_to_list_bottom
            self[:position] = bottom_position_in_list.to_i + 1
          end


          # Returns the bottom position number in the list.
          #   bottom_position_in_list    # => 2
          def bottom_position_in_list(except = nil)
            item = bottom_item(except)
            item ? item.send(:position) : 0
          end

          # Returns the bottom item
          def bottom_item(except = nil)
            conditions = "#{self.class.primary_key} != #{except.id}" if except
            acts_as_list_class.find(:first, :conditions => conditions, :order => "#{:position} DESC")
          end

          # Forces item to assume the bottom position in the list.
          def assume_bottom_position
            update_attribute(:position, bottom_position_in_list(self).to_i + 1)
          end

          # Forces item to assume the top position in the list.
          def assume_top_position
            update_attribute(:position, 1)
          end


          # This has the effect of moving all the lower items up one.
          def decrement_positions_on_lower_items
            return unless in_list?
            acts_as_list_class.update_all(
              "#{:position} = (#{:position} - 1)", "#{:position} > #{send(:position).to_i}"
            )
          end

          # This has the effect of moving all the higher items down one.
          def increment_positions_on_higher_items
            return unless in_list?
            acts_as_list_class.update_all(
              "#{:position} = (#{:position} + 1)", "#{:position} < #{send(:position).to_i}"
            )
          end
      end 
    end
  end
end