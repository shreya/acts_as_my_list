module ActiveRecord
  module Acts 
    module MyList 
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_my_list(options = {})
          configuration = { :column => "position", :scope => "1 = 1" }

          class_eval <<-EOV
            include ActiveRecord::Acts::List::InstanceMethods

            def acts_as_list_class
              ::#{self.name}
            end

            def position_column
              '#{configuration[:column]}'
            end

            before_destroy :decrement_positions_on_lower_items
            before_create  :add_to_list_bottom
          EOV
        end
      end

      module InstanceMethods
        # Insert the item at the given position (defaults to the top position of 1).
        def insert_at(position = 1)
          insert_at_position(position)
        end

        # Swap positions with the next lower item, if one exists.
        def move_lower
          return unless lower_item

          acts_as_list_class.transaction do
            lower_item.decrement_position
            increment_position
          end
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

        # Removes the item from the list.
        def remove_from_list
          if in_list?
            decrement_positions_on_lower_items
            update_attribute position_column, nil
          end
        end

        # Return +true+ if this object is the first in the list.
        def first?
          return false unless in_list?
          self.send(position_column) == 1
        end

        # Return +true+ if this object is the last in the list.
        def last?
          return false unless in_list?
          self.send(position_column) == bottom_position_in_list
        end


        private
          def add_to_list_top
            increment_positions_on_all_items
          end

          def add_to_list_bottom
            self[position_column] = bottom_position_in_list.to_i + 1
          end

          # Overwrite this method to define the scope of the list changes
          def scope_condition() "1" end

          # Returns the bottom position number in the list.
          #   bottom_position_in_list    # => 2
          def bottom_position_in_list(except = nil)
            item = bottom_item(except)
            item ? item.send(position_column) : 0
          end

          # Returns the bottom item
          def bottom_item(except = nil)
            conditions = "#{self.class.primary_key} != #{except.id}" if except
            acts_as_list_class.find(:first, :conditions => conditions, :order => "#{position_column} DESC")
          end

          # Forces item to assume the bottom position in the list.
          def assume_bottom_position
            update_attribute(position_column, bottom_position_in_list(self).to_i + 1)
          end

          # Forces item to assume the top position in the list.
          def assume_top_position
            update_attribute(position_column, 1)
          end

          # This has the effect of moving all the higher items up one.
          def decrement_positions_on_higher_items(position)
            acts_as_list_class.update_all(
              "#{position_column} = (#{position_column} - 1)", "#{position_column} <= #{position}"
            )
          end

          # This has the effect of moving all the lower items up one.
          def decrement_positions_on_lower_items
            return unless in_list?
            acts_as_list_class.update_all(
              "#{position_column} = (#{position_column} - 1)", "#{position_column} > #{send(position_column).to_i}"
            )
          end

          # This has the effect of moving all the higher items down one.
          def increment_positions_on_higher_items
            return unless in_list?
            acts_as_list_class.update_all(
              "#{position_column} = (#{position_column} + 1)", "#{position_column} < #{send(position_column).to_i}"
            )
          end

          # This has the effect of moving all the lower items down one.
          def increment_positions_on_lower_items(position)
            acts_as_list_class.update_all(
              "#{position_column} = (#{position_column} + 1)", "#{position_column} >= #{position}"
           )
          end

          # Increments position (<tt>position_column</tt>) of all items in the list.
          def increment_positions_on_all_items
            acts_as_list_class.update_all(
              "#{position_column} = (#{position_column} + 1)"
            )
          end

          def insert_at_position(position)
            remove_from_list
            increment_positions_on_lower_items(position)
            self.update_attribute(position_column, position)
          end
      end 
    end
  end
end



  