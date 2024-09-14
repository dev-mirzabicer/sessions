import os

def tree(path, indent=""):
  """
  Recursively prints the directory structure and file contents like the 'tree' command.

  Args:
    path: The path to the directory to start from.
    indent: The indentation string to use for subdirectories.
  """

  print(indent + os.path.basename(path))

  for item in os.listdir(path):
    item_path = os.path.join(path, item)
    if os.path.isdir(item_path):
      tree(item_path, indent + "  ")
    else:
      print(indent + "  " + item)
      try:
        with open(item_path, "r") as f:
          print(indent + "    " + "---- File Content ----")
          for line in f:
            print(indent + "    " + line.strip())
          print(indent + "    " + "---------------------")
      except UnicodeDecodeError:
        print(indent + "    " + "[Binary File - Content Not Displayed]")


if __name__ == "__main__":
  import sys
  if len(sys.argv) > 1:
    start_path = sys.argv[1]
  else:
    start_path = "."  # Default to current directory

  tree(start_path) 
