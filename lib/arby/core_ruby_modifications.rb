# Defines the instance method 'find_by_name' for the core Ruby class Array.
class Array
  # Finds and returns an element, by its 'name' attribute.
  def find_by_name(name)
    index = self.index {|x| x.name == name }
    self[index]
  end
end
