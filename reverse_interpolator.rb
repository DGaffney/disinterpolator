require 'levenshtein'
require 'csv'
require 'pry'
load 'array.rb'
class ReverseInterpolator
  def initialize(interpolated_texts)
    @interpolated_texts = interpolated_texts
  end
  
  def run
    nodes, edges = generate_markov_network
    node_frequency_cutoff = generate_node_cutoff(nodes)
    edge_frequency_cutoff = generate_edge_cutoff(edges)
    generate_generalized_pairs(nodes, edges, node_frequency_cutoff, edge_frequency_cutoff)
  end

  def generate_markov_network
    nodes = {}
    edges = {}
    @interpolated_texts.compact.reject(&:empty?).each do |x,kk|
      words = {}
      position = 0
      split = x.split(" ")
      split.each_with_index do |word, word_index|
        next_word = split[word_index+1]
        word_is_last = next_word.nil?
        if words[word]
          words[word] += 1
        else
          words[word] = 0
        end
        if !word_is_last
          edges[word+"||"+words[word].to_s] ||= {}
          edges[word+"||"+words[word].to_s][next_word+"||"+(words[next_word].nil? ? 0 : words[next_word]+1).to_s] ||= {positions: [], occurrences: []}
          edges[word+"||"+words[word].to_s][next_word+"||"+(words[next_word].nil? ? 0 : words[next_word]+1).to_s][:positions] << position
          edges[word+"||"+words[word].to_s][next_word+"||"+(words[next_word].nil? ? 0 : words[next_word]+1).to_s][:occurrences] << position
        end
        nodes[word+"||"+words[word].to_s] ||= 0
        nodes[word+"||"+words[word].to_s] += 1
      end
    end
    return nodes, edges
  end
  
  def generate_node_cutoff(nodes)
    distinct_node_counts = nodes.values.sort.uniq
    counts = []
    distinct_node_counts[1..-1].each_with_index do |val, i|
      counts << val-distinct_node_counts[i]
    end
    distinct_node_counts[counts.index(counts.max)-2]
  end

  def generate_edge_cutoff(edges)
    distinct_edge_counts = edges.values.collect{|e| e.values.collect{|x| x[:positions].length}}.flatten.sort.uniq
    counts = []
    distinct_edge_counts[1..-1].each_with_index do |val, i|
      counts << val-distinct_edge_counts[i]
    end
    distinct_edge_counts[counts.index(counts.max)+1]
  end
  
  def generate_generalized_pairs(nodes, edges, node_frequency_cutoff, edge_frequency_cutoff)
    generalized_interpolations = []
    individual_interpolations = []
    variable_sets = []
    @interpolated_texts.compact.reject(&:empty?).each_with_index do |sentence, ii|
      variable_set = []
      if sentence.split(" ").length == 1
        generalized_interpolations << sentence
      end
      var_count = 0
      words = {}
      generalized_interpolation = []
      split_sentence = sentence.split(" ")
      split_sentence.each_with_index do |word, word_index|
        next_word = split_sentence[word_index+1]
        word_is_last = next_word.nil?
        if words[word]
          words[word] += 1
        else
          words[word] = 0
        end
        if nodes[word+"||"+words[word].to_s] < node_frequency_cutoff and (word_is_last || edges[word+"||"+words[word].to_s][next_word+"||"+(words[next_word].nil? ? 0 : words[next_word]+1).to_s][:positions].length < edge_frequency_cutoff)
          generalized_interpolation << "{{{variable}}}" if generalized_interpolation.last != "{{{variable}}}"
          variable_set << word
        else
          generalized_interpolation << word
        end
      end
      generalized_interpolations << generalized_interpolation
      individual_interpolations << sentence
      variable_sets << variable_set
    end;false
    return [individual_interpolations, generalized_interpolations, variable_sets].transpose
  end
  
  def self.test_system
    interpolation_data = CSV.read("test_data.csv")[1..-1];false
    full_results = []
    likelihoods = [[0,0,0], [0,0,0.5], [0,0.33,0.33], [0.25,0.5,0.75]]
    likelihood_counts = [1, 2, 3, 4]
    [100, 200, 500, 1000, 5000, 10000, 20000, 50000, 100000].each do |scale|
      likelihoods.each_with_index do |likelihood_set, index|
        interpolations = []
        checks = []
        variables = []
        interpolation_data.first(scale).each do |interpolation_set|
          if rand < likelihood_set[0]
            interpolations << "This is an example of #{interpolation_set[0]} where another is #{interpolation_set[1]}."
            checks << "This is an example of {{{variable}}} where another is {{{variable}}}"
            variables << [interpolation_set[0], interpolation_set[1]].flatten.join(" ").split(" ")
          elsif rand < likelihood_set[1]
            interpolations << "And here's #{interpolation_set[0]}."
            checks << "And here's {{{variable}}}"
            variables << [interpolation_set[0]].flatten.join(" ").split(" ")
          elsif rand < likelihood_set[2]
            interpolations << "Yet another person, #{interpolation_set[0]}, who has #{interpolation_set[1]} followers and a bio of #{interpolation_set[2]}."
            checks << "Yet another person, {{{variable}}} who has {{{variable}}} followers and a bio of {{{variable}}}"
            variables << [interpolation_set[0], interpolation_set[1], interpolation_set[2]].flatten.join(" ").split(" ")
          else
            interpolations << "#{interpolation_set[0]} has a follower count of #{interpolation_set[1]}, and their biography is \"#{interpolation_set[2]}\"."
            checks << "{{{variable}}} has a follower count of {{{variable}}} and their biography is {{{variable}}}"
            variables << [interpolation_set[0], interpolation_set[1], interpolation_set[2]].flatten.join(" ").split(" ")
          end
        end
        results = ReverseInterpolator.new(interpolations).run;false
        test_results = ReverseInterpolator.assess_results(results, interpolations, checks, variables)
        full_results << {mutual_information_perfect: test_results[9], mutual_information_min: test_results[5], mutual_information_median: test_results[6], mutual_information_average: test_results[7], mutual_information_max: test_results[8], levenshtein_perfect: test_results[4], levenshtein_min: test_results[0], levenshtein_median: test_results[1], levenshtein_average: test_results[2], levenshtein_max: test_results[3], dimensions: likelihood_counts[index], scale: scale}
        puts full_results.last
      end
    end
    csv = CSV.open("results.csv", "w")
    keys = [:mutual_information_perfect, :mutual_information_min, :mutual_information_median, :mutual_information_average, :mutual_information_max, :levenshtein_perfect, :levenshtein_min, :levenshtein_median, :levenshtein_average, :levenshtein_max, :dimensions, :scale]
    csv << keys
    full_results.each do |result|
      csv << keys.collect{|x| result[x]}
    end
    csv.close
    full_results
  end
  
  def self.assess_results(results, interpolations, checks, variables)
    scores = []
    mutual_information = []
    results.each_with_index do |result, result_index|
      scores << Levenshtein.distance(result[1].join(" "), checks[result_index])
      known_variables = variables[result_index].collect{|w| w.downcase.gsub(/[^a-z0-9\s]/i, '')}
      extracted_variables = result.last.collect{|w| w.downcase.gsub(/[^a-z0-9\s]/i, '')}
      mutual_information << (known_variables&extracted_variables).count.to_f/(known_variables|extracted_variables).count
    end
    return [scores.min, scores.median, scores.average, scores.max, scores.count(0), mutual_information.min, mutual_information.median, mutual_information.average, mutual_information.max, mutual_information.count(1)]
  end
end
