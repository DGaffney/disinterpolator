class Array
  def sum
    return self.collect(&:to_f).inject(0){|acc,i|acc +i}
  end
  def average
    return self.sum/self.length.to_f
  end
  def median
    return nil if self.empty?
    self.sort!
    if self.length % 2 == 0
      median_value = (self[self.length / 2] + self[self.length/2 - 1]) / 2.0
    else
      median_value = self[self.length / 2]
    end
  end
end