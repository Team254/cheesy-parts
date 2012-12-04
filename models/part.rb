# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a single part or assembly in a project.

class Part < Sequel::Model
  many_to_one :project
  many_to_one :parent_part, :class => self
  one_to_many :child_parts, :key => :parent_part_id, :class => self

  def self.generate_number_and_create(project, type, name, parent_part, notes)
    parent_part_id = parent_part.nil? ? 0 : parent_part.id
    parent_part_number = parent_part.nil? ? 0 : parent_part.part_number
    if type == "part"
      part_number = Part.filter(:parent_part_id => parent_part_id).max(:part_number) || parent_part_number
      part_number += 1
    else
      part_number = Part.filter(:type => "assembly").max(:part_number)  || -100
      part_number += 100
    end
    create(:part_number => part_number, :project_id => project.id, :type => type, :name => name,
           :parent_part_id => parent_part.nil? ? 0 : parent_part.id, :notes => notes, :status => "designing")
  end

  def full_part_number
    "%d%04d" % [project.part_number_prefix, part_number]
  end
end
